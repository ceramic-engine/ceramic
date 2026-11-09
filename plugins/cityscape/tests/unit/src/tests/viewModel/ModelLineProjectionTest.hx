// Ported from vscode src/vs/editor/test/browser/viewModel/modelLineProjection.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.viewModel;

import cityscape.common.EncodedTokenAttributes.MetadataConsts;
import cityscape.common.Model.EndOfLinePreference;
import cityscape.common.ModelLineProjectionData;
import cityscape.common.ViewModel.ViewLineData;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.tokens.LineTokens;
import cityscape.common.viewModel.ModelLineProjection;
import cityscape.common.viewModel.MonospaceLineBreaksComputer;
import cityscape.common.viewModel.ViewModelLines;
import cityscape.view.config.EditorConfiguration;
import testing.TestCase;
import cityscape.common.model.TextModel;
import cityscape.Cityscape;
import cityscape.common.Languages.EncodedTokenizationResult;
import cityscape.common.languages.NullTokenize;
import haxe.io.UInt32Array;
import testing.TestTokenizationSupport;
import tests.TestTextModel;
import tests.TestTextModel.createTextModel;

typedef ITestViewLineToken = {
    endIndex:Int,
    value:Int
}

typedef ITestMinimapLineRenderingData = {
    content:String,
    minColumn:Int,
    maxColumn:Int,
    tokens:Array<ITestViewLineToken>
}

/**
 * suite('Editor ViewModel - SplitLinesCollection') and
 * suite('SplitLinesCollection') (tests of the second suite prefixed with
 * `Suite2`).
 *
 * Monaco's global `TokenizationRegistry` is the registry of the model's
 * `Cityscape` context.
 */
class ModelLineProjectionTest extends TestCase {

    static function pos(lineNumber:Int, column:Int):Position {
        return new Position(lineNumber, column);
    }

    static function createSplitLine(splitLengths:Array<Int>, breakingOffsetsVisibleColumn:Array<Float>, wrappedTextIndentWidth:Int, isVisible:Bool = true):IModelLineProjection {
        return ModelLineProjections.createModelLineProjection(createLineBreakData(splitLengths, breakingOffsetsVisibleColumn, wrappedTextIndentWidth), isVisible);
    }

    static function createLineBreakData(breakingLengths:Array<Int>, breakingOffsetsVisibleColumn:Array<Float>, wrappedTextIndentWidth:Int):ModelLineProjectionData {
        final sums:Array<Int> = [];
        for (i in 0...breakingLengths.length) {
            sums[i] = (i > 0 ? sums[i - 1] : 0) + breakingLengths[i];
        }
        return new ModelLineProjectionData(null, null, sums, breakingOffsetsVisibleColumn, wrappedTextIndentWidth);
    }

    static function createModel(text:String):ISimpleModel {
        return new SimpleTextModel(text);
    }

    function withSplitLinesCollection(text:String, callback:(model:TextModel, linesCollection:ViewModelLinesFromProjectedModel) -> Void):Void {
        final config = new EditorConfiguration(false, {});
        final wrappingInfo = config.options.get(EditorOption.wrappingInfo);
        final fontInfo = config.options.get(EditorOption.fontInfo);
        final wordWrapBreakAfterCharacters = config.options.get(EditorOption.wordWrapBreakAfterCharacters);
        final wordWrapBreakBeforeCharacters = config.options.get(EditorOption.wordWrapBreakBeforeCharacters);
        final wrappingIndent = config.options.get(EditorOption.wrappingIndent);
        final wordBreak = config.options.get(EditorOption.wordBreak);
        final lineBreaksComputerFactory = new MonospaceLineBreaksComputerFactory(wordWrapBreakBeforeCharacters, wordWrapBreakAfterCharacters);

        final model = createTextModel([
            'int main() {',
            '\tprintf("Hello world!");',
            '}',
            'int main() {',
            '\tprintf("Hello world!");',
            '}',
        ].join('\n'));

        final linesCollection = new ViewModelLinesFromProjectedModel(
            1,
            model,
            lineBreaksComputerFactory,
            lineBreaksComputerFactory,
            fontInfo,
            model.getOptions().tabSize,
            'simple',
            wrappingInfo.wrappingColumn,
            wrappingIndent,
            wordBreak
        );

        callback(model, linesCollection);

        linesCollection.dispose();
        model.dispose();
        config.dispose();
    }

    // suite('SplitLinesCollection')

    static final _text = [
        'class Nice {',
        '\tfunction hi() {',
        '\t\tconsole.log("Hello world");',
        '\t}',
        '\tfunction hello() {',
        '\t\tconsole.log("Hello world, this is a somewhat longer line");',
        '\t}',
        '}',
    ];

    static final _tokens:Array<Array<{startIndex:Int, value:Int}>> = [
        [
            {startIndex: 0, value: 1},
            {startIndex: 5, value: 2},
            {startIndex: 6, value: 3},
            {startIndex: 10, value: 4},
        ],
        [
            {startIndex: 0, value: 5},
            {startIndex: 1, value: 6},
            {startIndex: 9, value: 7},
            {startIndex: 10, value: 8},
            {startIndex: 12, value: 9},
        ],
        [
            {startIndex: 0, value: 10},
            {startIndex: 2, value: 11},
            {startIndex: 9, value: 12},
            {startIndex: 10, value: 13},
            {startIndex: 13, value: 14},
            {startIndex: 14, value: 15},
            {startIndex: 27, value: 16},
        ],
        [
            {startIndex: 0, value: 17},
        ],
        [
            {startIndex: 0, value: 18},
            {startIndex: 1, value: 19},
            {startIndex: 9, value: 20},
            {startIndex: 10, value: 21},
            {startIndex: 15, value: 22},
        ],
        [
            {startIndex: 0, value: 23},
            {startIndex: 2, value: 24},
            {startIndex: 9, value: 25},
            {startIndex: 10, value: 26},
            {startIndex: 13, value: 27},
            {startIndex: 14, value: 28},
            {startIndex: 59, value: 29},
        ],
        [
            {startIndex: 0, value: 30},
        ],
        [
            {startIndex: 0, value: 31},
        ]
    ];

    var model:TextModel;
    var languageRegistration:Null<cityscape.base.common.Lifecycle.IDisposable> = null;

    override public function setup():Void {
        var _lineIndex = 0;
        final tokenizationSupport = new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line, hasEOL, state) -> {
                final tokens = _tokens[_lineIndex++];
                final result = new UInt32Array(2 * tokens.length);
                for (i in 0...tokens.length) {
                    result[2 * i] = tokens[i].startIndex;
                    result[2 * i + 1] = (tokens[i].value << MetadataConsts.FOREGROUND_OFFSET);
                }
                return new EncodedTokenizationResult(result, state);
            }
        );
        final LANGUAGE_ID = 'modelModeTest1';
        // Monaco registers in the global registry: here in the model's context
        final context = new Cityscape();
        languageRegistration = context.tokenizationRegistry.register(LANGUAGE_ID, tokenizationSupport);
        model = TestTextModel.instantiateTextModel(context, _text.join('\n'), LANGUAGE_ID);
        // force tokenization
        model.tokenization.forceTokenization(model.getLineCount());
    }

    override public function teardown():Void {
        model.dispose();
        languageRegistration.dispose();
    }

    function assertViewLineTokens(_actual:cityscape.common.tokens.LineTokens.IViewLineTokens, expected:Array<ITestViewLineToken>, ?pos:haxe.PosInfos):Void {
        final actual:Array<ITestViewLineToken> = [];
        for (i in 0..._actual.getCount()) {
            actual[i] = {
                endIndex: _actual.getEndOffset(i),
                value: _actual.getForeground(i)
            };
        }
        assertDeepEquals(expected, actual, null, pos);
    }

    function assertMinimapLineRenderingData(actual:Null<ViewLineData>, expected:Null<ITestMinimapLineRenderingData>, ?pos:haxe.PosInfos):Void {
        if (actual == null && expected == null) {
            assertTrue(true);
            return;
        }
        if (expected == null || actual == null) {
            assertTrue(false, null, pos);
            return;
        }
        assertEquals(expected.content, actual.content, null, pos);
        assertEquals(expected.minColumn, actual.minColumn, null, pos);
        assertEquals(expected.maxColumn, actual.maxColumn, null, pos);
        assertViewLineTokens(actual.tokens, expected.tokens, pos);
    }

    function assertMinimapLinesRenderingData(actual:Array<Null<ViewLineData>>, expected:Array<Null<ITestMinimapLineRenderingData>>, ?pos:haxe.PosInfos):Void {
        assertEquals(expected.length, actual.length, null, pos);
        for (i in 0...expected.length) {
            assertMinimapLineRenderingData(actual[i], expected[i], pos);
        }
    }

    function assertAllMinimapLinesRenderingData(splitLinesCollection:ViewModelLinesFromProjectedModel, all:Array<ITestMinimapLineRenderingData>, ?pos:haxe.PosInfos):Void {
        final lineCount = all.length;
        for (line in 1...lineCount + 1) {
            assertEquals(splitLinesCollection.getViewLineContent(line), splitLinesCollection.getViewLineData(line).content, null, pos);
        }

        for (start in 1...lineCount + 1) {
            for (end in start...lineCount + 1) {
                final count = end - start + 1;
                var desired = Std.int(Math.pow(2, count)) - 1;
                while (desired >= 0) {
                    final needed:Array<Bool> = [];
                    final expected:Array<Null<ITestMinimapLineRenderingData>> = [];
                    for (i in 0...count) {
                        needed[i] = (desired & (1 << i)) != 0 ? true : false;
                        expected[i] = (needed[i] ? all[start - 1 + i] : null);
                    }
                    final actual = splitLinesCollection.getViewLinesData(start, end, needed);

                    assertMinimapLinesRenderingData(actual, expected, pos);
                    // Comment out next line to test all possible combinations
                    break;
                }
            }
        }
    }

    function withSplitLinesCollection2(model:TextModel, wordWrap:String, wordWrapColumn:Int, callback:(splitLinesCollection:ViewModelLinesFromProjectedModel) -> Void):Void {
        final configuration = new EditorConfiguration(false, {
            wordWrap: wordWrap,
            wordWrapColumn: wordWrapColumn,
            wrappingIndent: 'indent'
        });
        final wrappingInfo = configuration.options.get(EditorOption.wrappingInfo);
        final fontInfo = configuration.options.get(EditorOption.fontInfo);
        final wordWrapBreakAfterCharacters = configuration.options.get(EditorOption.wordWrapBreakAfterCharacters);
        final wordWrapBreakBeforeCharacters = configuration.options.get(EditorOption.wordWrapBreakBeforeCharacters);
        final wrappingIndent = configuration.options.get(EditorOption.wrappingIndent);
        final wordBreak = configuration.options.get(EditorOption.wordBreak);

        final lineBreaksComputerFactory = new MonospaceLineBreaksComputerFactory(wordWrapBreakBeforeCharacters, wordWrapBreakAfterCharacters);

        final linesCollection = new ViewModelLinesFromProjectedModel(
            1,
            model,
            lineBreaksComputerFactory,
            lineBreaksComputerFactory,
            fontInfo,
            model.getOptions().tabSize,
            'simple',
            wrappingInfo.wrappingColumn,
            wrappingIndent,
            wordBreak
        );

        callback(linesCollection);

        configuration.dispose();
    }

    // test('SplitLine')
    function testSplitLine() {
        var model1 = createModel('My First LineMy Second LineAnd another one');
        var line1 = createSplitLine([13, 14, 15], [13, 13 + 14, 13 + 14 + 15], 0);

        assertEquals(line1.getViewLineCount(), 3);
        assertEquals(line1.getViewLineContent(model1, 1, 0), 'My First Line');
        assertEquals(line1.getViewLineContent(model1, 1, 1), 'My Second Line');
        assertEquals(line1.getViewLineContent(model1, 1, 2), 'And another one');
        assertEquals(line1.getViewLineMaxColumn(model1, 1, 0), 14);
        assertEquals(line1.getViewLineMaxColumn(model1, 1, 1), 15);
        assertEquals(line1.getViewLineMaxColumn(model1, 1, 2), 16);
        for (col in (1)...(14) + 1) {
            assertEquals(line1.getModelColumnOfViewPosition(0, col), col, 'getInputColumnOfOutputPosition(0, ' + col + ')');
        }
        for (col in (1)...(15) + 1) {
            assertEquals(line1.getModelColumnOfViewPosition(1, col), 13 + col, 'getInputColumnOfOutputPosition(1, ' + col + ')');
        }
        for (col in (1)...(16) + 1) {
            assertEquals(line1.getModelColumnOfViewPosition(2, col), 13 + 14 + col, 'getInputColumnOfOutputPosition(2, ' + col + ')');
        }
        for (col in (1)...(13) + 1) {
            assertDeepEquals(line1.getViewPositionOfModelPosition(0, col), pos(0, col), 'getOutputPositionOfInputPosition(' + col + ')');
        }
        for (col in (1 + 13)...(14 + 13) + 1) {
            assertDeepEquals(line1.getViewPositionOfModelPosition(0, col), pos(1, col - 13), 'getOutputPositionOfInputPosition(' + col + ')');
        }
        for (col in (1 + 13 + 14)...(15 + 14 + 13) + 1) {
            assertDeepEquals(line1.getViewPositionOfModelPosition(0, col), pos(2, col - 13 - 14), 'getOutputPositionOfInputPosition(' + col + ')');
        }

        model1 = createModel('My First LineMy Second LineAnd another one');
        line1 = createSplitLine([13, 14, 15], [13, 13 + 14, 13 + 14 + 15], 4);

        assertEquals(line1.getViewLineCount(), 3);
        assertEquals(line1.getViewLineContent(model1, 1, 0), 'My First Line');
        assertEquals(line1.getViewLineContent(model1, 1, 1), '    My Second Line');
        assertEquals(line1.getViewLineContent(model1, 1, 2), '    And another one');
        assertEquals(line1.getViewLineMaxColumn(model1, 1, 0), 14);
        assertEquals(line1.getViewLineMaxColumn(model1, 1, 1), 19);
        assertEquals(line1.getViewLineMaxColumn(model1, 1, 2), 20);

        final actualViewColumnMapping:Array<Array<Int>> = [];
        for (lineIndex in (0)...(line1.getViewLineCount())) {
            final actualLineViewColumnMapping:Array<Int> = [];
            for (col in (1)...(line1.getViewLineMaxColumn(model1, 1, lineIndex)) + 1) {
                actualLineViewColumnMapping.push(line1.getModelColumnOfViewPosition(lineIndex, col));
            }
            actualViewColumnMapping.push(actualLineViewColumnMapping);
        }
        assertDeepEquals(actualViewColumnMapping, [
            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
            [14, 14, 14, 14, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
            [28, 28, 28, 28, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43],
        ]);

        for (col in (1)...(13) + 1) {
            assertDeepEquals(line1.getViewPositionOfModelPosition(0, col), pos(0, col), '6.getOutputPositionOfInputPosition(' + col + ')');
        }
        for (col in (1 + 13)...(14 + 13) + 1) {
            assertDeepEquals(line1.getViewPositionOfModelPosition(0, col), pos(1, 4 + col - 13), '7.getOutputPositionOfInputPosition(' + col + ')');
        }
        for (col in (1 + 13 + 14)...(15 + 14 + 13) + 1) {
            assertDeepEquals(line1.getViewPositionOfModelPosition(0, col), pos(2, 4 + col - 13 - 14), '8.getOutputPositionOfInputPosition(' + col + ')');
        }
    }

    // test('Invalid line numbers')
    function testInvalidLineNumbers() {

        final text = [
            'int main() {',
            '\tprintf("Hello world!");',
            '}',
            'int main() {',
            '\tprintf("Hello world!");',
            '}',
        ].join('\n');

        withSplitLinesCollection(text, (model, linesCollection) -> {
            assertEquals(linesCollection.getViewLineCount(), 6);

            // getOutputIndentGuide
            assertDeepEquals(linesCollection.getViewLinesIndentGuides(-1, -1), [0]);
            assertDeepEquals(linesCollection.getViewLinesIndentGuides(0, 0), [0]);
            assertDeepEquals(linesCollection.getViewLinesIndentGuides(1, 1), [0]);
            assertDeepEquals(linesCollection.getViewLinesIndentGuides(2, 2), [1]);
            assertDeepEquals(linesCollection.getViewLinesIndentGuides(3, 3), [0]);
            assertDeepEquals(linesCollection.getViewLinesIndentGuides(4, 4), [0]);
            assertDeepEquals(linesCollection.getViewLinesIndentGuides(5, 5), [1]);
            assertDeepEquals(linesCollection.getViewLinesIndentGuides(6, 6), [0]);
            assertDeepEquals(linesCollection.getViewLinesIndentGuides(7, 7), [0]);

            assertDeepEquals(linesCollection.getViewLinesIndentGuides(0, 7), [0, 1, 0, 0, 1, 0]);

            // getOutputLineContent
            assertEquals(linesCollection.getViewLineContent(-1), 'int main() {');
            assertEquals(linesCollection.getViewLineContent(0), 'int main() {');
            assertEquals(linesCollection.getViewLineContent(1), 'int main() {');
            assertEquals(linesCollection.getViewLineContent(2), '\tprintf("Hello world!");');
            assertEquals(linesCollection.getViewLineContent(3), '}');
            assertEquals(linesCollection.getViewLineContent(4), 'int main() {');
            assertEquals(linesCollection.getViewLineContent(5), '\tprintf("Hello world!");');
            assertEquals(linesCollection.getViewLineContent(6), '}');
            assertEquals(linesCollection.getViewLineContent(7), '}');

            // getOutputLineMinColumn
            assertEquals(linesCollection.getViewLineMinColumn(-1), 1);
            assertEquals(linesCollection.getViewLineMinColumn(0), 1);
            assertEquals(linesCollection.getViewLineMinColumn(1), 1);
            assertEquals(linesCollection.getViewLineMinColumn(2), 1);
            assertEquals(linesCollection.getViewLineMinColumn(3), 1);
            assertEquals(linesCollection.getViewLineMinColumn(4), 1);
            assertEquals(linesCollection.getViewLineMinColumn(5), 1);
            assertEquals(linesCollection.getViewLineMinColumn(6), 1);
            assertEquals(linesCollection.getViewLineMinColumn(7), 1);

            // getOutputLineMaxColumn
            assertEquals(linesCollection.getViewLineMaxColumn(-1), 13);
            assertEquals(linesCollection.getViewLineMaxColumn(0), 13);
            assertEquals(linesCollection.getViewLineMaxColumn(1), 13);
            assertEquals(linesCollection.getViewLineMaxColumn(2), 25);
            assertEquals(linesCollection.getViewLineMaxColumn(3), 2);
            assertEquals(linesCollection.getViewLineMaxColumn(4), 13);
            assertEquals(linesCollection.getViewLineMaxColumn(5), 25);
            assertEquals(linesCollection.getViewLineMaxColumn(6), 2);
            assertEquals(linesCollection.getViewLineMaxColumn(7), 2);

            // convertOutputPositionToInputPosition
            assertDeepEquals(linesCollection.convertViewPositionToModelPosition(-1, 1), new Position(1, 1));
            assertDeepEquals(linesCollection.convertViewPositionToModelPosition(0, 1), new Position(1, 1));
            assertDeepEquals(linesCollection.convertViewPositionToModelPosition(1, 1), new Position(1, 1));
            assertDeepEquals(linesCollection.convertViewPositionToModelPosition(2, 1), new Position(2, 1));
            assertDeepEquals(linesCollection.convertViewPositionToModelPosition(3, 1), new Position(3, 1));
            assertDeepEquals(linesCollection.convertViewPositionToModelPosition(4, 1), new Position(4, 1));
            assertDeepEquals(linesCollection.convertViewPositionToModelPosition(5, 1), new Position(5, 1));
            assertDeepEquals(linesCollection.convertViewPositionToModelPosition(6, 1), new Position(6, 1));
            assertDeepEquals(linesCollection.convertViewPositionToModelPosition(7, 1), new Position(6, 1));
            assertDeepEquals(linesCollection.convertViewPositionToModelPosition(8, 1), new Position(6, 1));
        });
    }

    // test('issue #3662')
    function testIssue3662() {

        final text = [
            'int main() {',
            '\tprintf("Hello world!");',
            '}',
            'int main() {',
            '\tprintf("Hello world!");',
            '}',
        ].join('\n');

        withSplitLinesCollection(text, (model, linesCollection) -> {
            linesCollection.setHiddenAreas([
                new Range(1, 1, 3, 1),
                new Range(5, 1, 6, 1)
            ]);

            final viewLineCount = linesCollection.getViewLineCount();
            assertEquals(viewLineCount, 1, 'getOutputLineCount()');

            final modelLineCount = model.getLineCount();
            for (lineNumber in (0)...(modelLineCount + 1) + 1) {
                final lineMinColumn = (lineNumber >= 1 && lineNumber <= modelLineCount) ? model.getLineMinColumn(lineNumber) : 1;
                final lineMaxColumn = (lineNumber >= 1 && lineNumber <= modelLineCount) ? model.getLineMaxColumn(lineNumber) : 1;
                for (column in (lineMinColumn - 1)...(lineMaxColumn + 1) + 1) {
                    final viewPosition = linesCollection.convertModelPositionToViewPosition(lineNumber, column);

                    // validate view position
                    var viewLineNumber = viewPosition.lineNumber;
                    var viewColumn = viewPosition.column;
                    if (viewLineNumber < 1) {
                        viewLineNumber = 1;
                    }
                    final lineCount = linesCollection.getViewLineCount();
                    if (viewLineNumber > lineCount) {
                        viewLineNumber = lineCount;
                    }
                    final viewMinColumn = linesCollection.getViewLineMinColumn(viewLineNumber);
                    final viewMaxColumn = linesCollection.getViewLineMaxColumn(viewLineNumber);
                    if (viewColumn < viewMinColumn) {
                        viewColumn = viewMinColumn;
                    }
                    if (viewColumn > viewMaxColumn) {
                        viewColumn = viewMaxColumn;
                    }
                    final validViewPosition = new Position(viewLineNumber, viewColumn);
                    assertEquals(viewPosition.toString(), validViewPosition.toString(), 'model->view for ' + lineNumber + ', ' + column);
                }
            }

            for (lineNumber in (0)...(viewLineCount + 1) + 1) {
                final lineMinColumn = linesCollection.getViewLineMinColumn(lineNumber);
                final lineMaxColumn = linesCollection.getViewLineMaxColumn(lineNumber);
                for (column in (lineMinColumn - 1)...(lineMaxColumn + 1) + 1) {
                    final modelPosition = linesCollection.convertViewPositionToModelPosition(lineNumber, column);
                    final validModelPosition = model.validatePosition(modelPosition);
                    assertEquals(modelPosition.toString(), validModelPosition.toString(), 'view->model for ' + lineNumber + ', ' + column);
                }
            }
        });
    }

    // test('getViewLinesData - no wrapping')
    function testSuite2GetViewLinesDataNoWrapping() {
        withSplitLinesCollection2(model, 'off', 0, (splitLinesCollection) -> {
            assertEquals(splitLinesCollection.getViewLineCount(), 8);
            assertEquals(splitLinesCollection.modelPositionIsVisible(1, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(2, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(3, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(4, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(5, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(6, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(7, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(8, 1), true);

            final _expected:Array<ITestMinimapLineRenderingData> = [
                {
                    content: 'class Nice {',
                    minColumn: 1,
                    maxColumn: 13,
                    tokens: [
                        { endIndex: 5, value: 1 },
                        { endIndex: 6, value: 2 },
                        { endIndex: 10, value: 3 },
                        { endIndex: 12, value: 4 },
                    ]
                },
                {
                    content: '\tfunction hi() {',
                    minColumn: 1,
                    maxColumn: 17,
                    tokens: [
                        { endIndex: 1, value: 5 },
                        { endIndex: 9, value: 6 },
                        { endIndex: 10, value: 7 },
                        { endIndex: 12, value: 8 },
                        { endIndex: 16, value: 9 },
                    ]
                },
                {
                    content: '\t\tconsole.log("Hello world");',
                    minColumn: 1,
                    maxColumn: 30,
                    tokens: [
                        { endIndex: 2, value: 10 },
                        { endIndex: 9, value: 11 },
                        { endIndex: 10, value: 12 },
                        { endIndex: 13, value: 13 },
                        { endIndex: 14, value: 14 },
                        { endIndex: 27, value: 15 },
                        { endIndex: 29, value: 16 },
                    ]
                },
                {
                    content: '\t}',
                    minColumn: 1,
                    maxColumn: 3,
                    tokens: [
                        { endIndex: 2, value: 17 },
                    ]
                },
                {
                    content: '\tfunction hello() {',
                    minColumn: 1,
                    maxColumn: 20,
                    tokens: [
                        { endIndex: 1, value: 18 },
                        { endIndex: 9, value: 19 },
                        { endIndex: 10, value: 20 },
                        { endIndex: 15, value: 21 },
                        { endIndex: 19, value: 22 },
                    ]
                },
                {
                    content: '\t\tconsole.log("Hello world, this is a somewhat longer line");',
                    minColumn: 1,
                    maxColumn: 62,
                    tokens: [
                        { endIndex: 2, value: 23 },
                        { endIndex: 9, value: 24 },
                        { endIndex: 10, value: 25 },
                        { endIndex: 13, value: 26 },
                        { endIndex: 14, value: 27 },
                        { endIndex: 59, value: 28 },
                        { endIndex: 61, value: 29 },
                    ]
                },
                {
                    minColumn: 1,
                    maxColumn: 3,
                    content: '\t}',
                    tokens: [
                        { endIndex: 2, value: 30 },
                    ]
                },
                {
                    minColumn: 1,
                    maxColumn: 2,
                    content: '}',
                    tokens: [
                        { endIndex: 1, value: 31 },
                    ]
                }
            ];

            assertAllMinimapLinesRenderingData(splitLinesCollection, [
                _expected[0],
                _expected[1],
                _expected[2],
                _expected[3],
                _expected[4],
                _expected[5],
                _expected[6],
                _expected[7],
            ]);

            splitLinesCollection.setHiddenAreas([new Range(2, 1, 4, 1)]);
            assertEquals(splitLinesCollection.getViewLineCount(), 5);
            assertEquals(splitLinesCollection.modelPositionIsVisible(1, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(2, 1), false);
            assertEquals(splitLinesCollection.modelPositionIsVisible(3, 1), false);
            assertEquals(splitLinesCollection.modelPositionIsVisible(4, 1), false);
            assertEquals(splitLinesCollection.modelPositionIsVisible(5, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(6, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(7, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(8, 1), true);

            assertAllMinimapLinesRenderingData(splitLinesCollection, [
                _expected[0],
                _expected[4],
                _expected[5],
                _expected[6],
                _expected[7],
            ]);
        });
    }

    // test('getViewLinesData - with wrapping')
    function testSuite2GetViewLinesDataWithWrapping() {
        withSplitLinesCollection2(model, 'wordWrapColumn', 30, (splitLinesCollection) -> {
            assertEquals(splitLinesCollection.getViewLineCount(), 12);
            assertEquals(splitLinesCollection.modelPositionIsVisible(1, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(2, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(3, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(4, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(5, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(6, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(7, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(8, 1), true);

            final _expected:Array<ITestMinimapLineRenderingData> = [
                {
                    content: 'class Nice {',
                    minColumn: 1,
                    maxColumn: 13,
                    tokens: [
                        { endIndex: 5, value: 1 },
                        { endIndex: 6, value: 2 },
                        { endIndex: 10, value: 3 },
                        { endIndex: 12, value: 4 },
                    ]
                },
                {
                    content: '\tfunction hi() {',
                    minColumn: 1,
                    maxColumn: 17,
                    tokens: [
                        { endIndex: 1, value: 5 },
                        { endIndex: 9, value: 6 },
                        { endIndex: 10, value: 7 },
                        { endIndex: 12, value: 8 },
                        { endIndex: 16, value: 9 },
                    ]
                },
                {
                    content: '\t\tconsole.log("Hello ',
                    minColumn: 1,
                    maxColumn: 22,
                    tokens: [
                        { endIndex: 2, value: 10 },
                        { endIndex: 9, value: 11 },
                        { endIndex: 10, value: 12 },
                        { endIndex: 13, value: 13 },
                        { endIndex: 14, value: 14 },
                        { endIndex: 21, value: 15 },
                    ]
                },
                {
                    content: '            world");',
                    minColumn: 13,
                    maxColumn: 21,
                    tokens: [
                        { endIndex: 18, value: 15 },
                        { endIndex: 20, value: 16 },
                    ]
                },
                {
                    content: '\t}',
                    minColumn: 1,
                    maxColumn: 3,
                    tokens: [
                        { endIndex: 2, value: 17 },
                    ]
                },
                {
                    content: '\tfunction hello() {',
                    minColumn: 1,
                    maxColumn: 20,
                    tokens: [
                        { endIndex: 1, value: 18 },
                        { endIndex: 9, value: 19 },
                        { endIndex: 10, value: 20 },
                        { endIndex: 15, value: 21 },
                        { endIndex: 19, value: 22 },
                    ]
                },
                {
                    content: '\t\tconsole.log("Hello ',
                    minColumn: 1,
                    maxColumn: 22,
                    tokens: [
                        { endIndex: 2, value: 23 },
                        { endIndex: 9, value: 24 },
                        { endIndex: 10, value: 25 },
                        { endIndex: 13, value: 26 },
                        { endIndex: 14, value: 27 },
                        { endIndex: 21, value: 28 },
                    ]
                },
                {
                    content: '            world, this is a ',
                    minColumn: 13,
                    maxColumn: 30,
                    tokens: [
                        { endIndex: 29, value: 28 },
                    ]
                },
                {
                    content: '            somewhat longer ',
                    minColumn: 13,
                    maxColumn: 29,
                    tokens: [
                        { endIndex: 28, value: 28 },
                    ]
                },
                {
                    content: '            line");',
                    minColumn: 13,
                    maxColumn: 20,
                    tokens: [
                        { endIndex: 17, value: 28 },
                        { endIndex: 19, value: 29 },
                    ]
                },
                {
                    content: '\t}',
                    minColumn: 1,
                    maxColumn: 3,
                    tokens: [
                        { endIndex: 2, value: 30 },
                    ]
                },
                {
                    content: '}',
                    minColumn: 1,
                    maxColumn: 2,
                    tokens: [
                        { endIndex: 1, value: 31 },
                    ]
                }
            ];

            assertAllMinimapLinesRenderingData(splitLinesCollection, [
                _expected[0],
                _expected[1],
                _expected[2],
                _expected[3],
                _expected[4],
                _expected[5],
                _expected[6],
                _expected[7],
                _expected[8],
                _expected[9],
                _expected[10],
                _expected[11],
            ]);

            splitLinesCollection.setHiddenAreas([new Range(2, 1, 4, 1)]);
            assertEquals(splitLinesCollection.getViewLineCount(), 8);
            assertEquals(splitLinesCollection.modelPositionIsVisible(1, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(2, 1), false);
            assertEquals(splitLinesCollection.modelPositionIsVisible(3, 1), false);
            assertEquals(splitLinesCollection.modelPositionIsVisible(4, 1), false);
            assertEquals(splitLinesCollection.modelPositionIsVisible(5, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(6, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(7, 1), true);
            assertEquals(splitLinesCollection.modelPositionIsVisible(8, 1), true);

            assertAllMinimapLinesRenderingData(splitLinesCollection, [
                _expected[0],
                _expected[5],
                _expected[6],
                _expected[7],
                _expected[8],
                _expected[9],
                _expected[10],
                _expected[11],
            ]);
        });
    }

    // test('getViewLinesData - with wrapping and injected text')
    function testSuite2GetViewLinesDataWithWrappingAndInjectedText() {
        model.deltaDecorations([], [{
            range: new Range(1, 9, 1, 9),
            options: {
                description: 'example',
                after: {
                    content: 'very very long injected text that causes a line break',
                    inlineClassName: 'myClassName'
                },
                showIfCollapsed: true,
            }
        }]);

        withSplitLinesCollection2(model, 'wordWrapColumn', 30, (splitLinesCollection) -> {
            assertEquals(splitLinesCollection.getViewLineCount(), 14);

            assertEquals(splitLinesCollection.getViewLineMaxColumn(1), 24);

            final _expected:Array<ITestMinimapLineRenderingData> = [
                {
                    content: 'class Nivery very long ',
                    minColumn: 1,
                    maxColumn: 24,
                    tokens: [
                        { endIndex: 5, value: 1 },
                        { endIndex: 6, value: 2 },
                        { endIndex: 8, value: 3 },
                        { endIndex: 23, value: 1 },
                    ]
                },
                {
                    content: '    injected text that causes ',
                    minColumn: 5,
                    maxColumn: 31,
                    tokens: [{ endIndex: 30, value: 1 }]
                },
                {
                    content: '    a line breakce {',
                    minColumn: 5,
                    maxColumn: 21,
                    tokens: [
                        { endIndex: 16, value: 1 },
                        { endIndex: 18, value: 3 },
                        { endIndex: 20, value: 4 }
                    ]
                },
                {
                    content: '\tfunction hi() {',
                    minColumn: 1,
                    maxColumn: 17,
                    tokens: [
                        { endIndex: 1, value: 5 },
                        { endIndex: 9, value: 6 },
                        { endIndex: 10, value: 7 },
                        { endIndex: 12, value: 8 },
                        { endIndex: 16, value: 9 },
                    ]
                },
                {
                    content: '\t\tconsole.log("Hello ',
                    minColumn: 1,
                    maxColumn: 22,
                    tokens: [
                        { endIndex: 2, value: 10 },
                        { endIndex: 9, value: 11 },
                        { endIndex: 10, value: 12 },
                        { endIndex: 13, value: 13 },
                        { endIndex: 14, value: 14 },
                        { endIndex: 21, value: 15 },
                    ]
                },
                {
                    content: '            world");',
                    minColumn: 13,
                    maxColumn: 21,
                    tokens: [
                        { endIndex: 18, value: 15 },
                        { endIndex: 20, value: 16 },
                    ]
                },
                {
                    content: '\t}',
                    minColumn: 1,
                    maxColumn: 3,
                    tokens: [
                        { endIndex: 2, value: 17 },
                    ]
                },
                {
                    content: '\tfunction hello() {',
                    minColumn: 1,
                    maxColumn: 20,
                    tokens: [
                        { endIndex: 1, value: 18 },
                        { endIndex: 9, value: 19 },
                        { endIndex: 10, value: 20 },
                        { endIndex: 15, value: 21 },
                        { endIndex: 19, value: 22 },
                    ]
                },
                {
                    content: '\t\tconsole.log("Hello ',
                    minColumn: 1,
                    maxColumn: 22,
                    tokens: [
                        { endIndex: 2, value: 23 },
                        { endIndex: 9, value: 24 },
                        { endIndex: 10, value: 25 },
                        { endIndex: 13, value: 26 },
                        { endIndex: 14, value: 27 },
                        { endIndex: 21, value: 28 },
                    ]
                },
                {
                    content: '            world, this is a ',
                    minColumn: 13,
                    maxColumn: 30,
                    tokens: [
                        { endIndex: 29, value: 28 },
                    ]
                },
                {
                    content: '            somewhat longer ',
                    minColumn: 13,
                    maxColumn: 29,
                    tokens: [
                        { endIndex: 28, value: 28 },
                    ]
                },
                {
                    content: '            line");',
                    minColumn: 13,
                    maxColumn: 20,
                    tokens: [
                        { endIndex: 17, value: 28 },
                        { endIndex: 19, value: 29 },
                    ]
                },
                {
                    content: '\t}',
                    minColumn: 1,
                    maxColumn: 3,
                    tokens: [
                        { endIndex: 2, value: 30 },
                    ]
                },
                {
                    content: '}',
                    minColumn: 1,
                    maxColumn: 2,
                    tokens: [
                        { endIndex: 1, value: 31 },
                    ]
                }
            ];

            assertAllMinimapLinesRenderingData(splitLinesCollection, [
                _expected[0],
                _expected[1],
                _expected[2],
                _expected[3],
                _expected[4],
                _expected[5],
                _expected[6],
                _expected[7],
                _expected[8],
                _expected[9],
                _expected[10],
                _expected[11],
            ]);

            final data = splitLinesCollection.getViewLinesData(1, 14, [for (_ in 0...14) true]);
            final actual:Array<Dynamic> = [for (d in data) {
                inlineDecorations: d.inlineDecorations == null ? null : [for (dec in d.inlineDecorations) {
                    startOffset: dec.startOffset,
                    endOffset: dec.endOffset,
                }],
            }];
            final expected:Array<Dynamic> = [
                {inlineDecorations: [{startOffset: 8, endOffset: 23}]},
                {inlineDecorations: [{startOffset: 4, endOffset: 30}]},
                {inlineDecorations: [{startOffset: 4, endOffset: 16}]},
            ];
            for (_ in 0...11) {
                expected.push({inlineDecorations: null});
            }
            assertDeepEquals(expected, actual
            );
        });
    }

}

private class SimpleTextModel implements ISimpleModel {

    final text:String;

    public function new(text:String) {
        this.text = text;
    }

    public function getLineTokens(lineNumber:Int):LineTokens {
        return null;
    }

    public function getLineContent(lineNumber:Int):String {
        return text;
    }

    public function getLineLength(lineNumber:Int):Int {
        return text.length;
    }

    public function getLineMinColumn(lineNumber:Int):Int {
        return 1;
    }

    public function getLineMaxColumn(lineNumber:Int):Int {
        return text.length + 1;
    }

    public function getValueInRange(range:cityscape.common.core.Range.IRange, ?eol:EndOfLinePreference):String {
        return text.substring(range.startColumn - 1, range.endColumn - 1);
    }

}
