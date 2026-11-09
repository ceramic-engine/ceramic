// Ported from vscode src/vs/editor/test/common/model/bracketPairColorizer/getBracketPairsInRange.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model.bracketPairColorizer;


import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Model.ITextModel;
import cityscape.common.TextModelBracketPairs;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import testing.TestCase;
import tests.TestTextModel;
import tests.model.bracketPairColorizer.TokenizerTest;

/**
 * suite('Bracket Pair Colorizer - getBracketPairsInRange')
 *
 * Runs on `testing.TestTextModel` until the real TextModel is ported.
 */
class GetBracketPairsInRangeTest extends TestCase {

    static function createTextModelWithColorizedBracketPairs(store:DisposableStore, text:String):ITextModel {
        final languageId = 'testLanguage';
        final context = new Cityscape();
        final languageConfigurationService = context.languageConfigurationService;
        final languageService = context.languageService;
        store.add(languageService.registerLanguage({
            id: languageId,
        }));

        final encodedMode1 = languageService.languageIdCodec.encodeLanguageId(languageId);
        final document = new TokenizedDocument([
            new TokenInfo(text, encodedMode1, StandardTokenType.Other, true)
        ]);
        store.add(context.tokenizationRegistry.register(languageId, document.getTokenizationSupport()));

        store.add(languageConfigurationService.register(languageId, {
            brackets: [
                ['<', '>']
            ],
            colorizedBracketPairs: [
                ['{', '}'],
                ['[', ']'],
                ['(', ')'],
            ]
        }));
        final textModel = TestTextModel.instantiateTextModel(context, text, languageId);
        // ITextModel is not an IDisposable in Cityscape (it has `dispose`)
        store.add(Lifecycle.toDisposable(() -> textModel.dispose()));
        return textModel;
    }

    function testBasic1() {
        final store = new DisposableStore();
        final doc = new AnnotatedDocument('{ ( [] ¹ ) [ ² { } ] () } []');
        final model = createTextModelWithColorizedBracketPairs(store, doc.text);
        model.tokenization.getLineTokens(1).getLanguageId(0);
        assertDeepEquals(
            model.bracketPairs
                .getBracketPairsInRange(doc.range(1, 2))
                .map(bracketPairToJSON)
                .toArray(),
            [
                {
                    level: 0,
                    range: '[1,1 -> 1,2]',
                    openRange: '[1,1 -> 1,2]',
                    closeRange: '[1,23 -> 1,24]',
                },
                {
                    level: 1,
                    range: '[1,3 -> 1,4]',
                    openRange: '[1,3 -> 1,4]',
                    closeRange: '[1,9 -> 1,10]',
                },
                {
                    level: 1,
                    range: '[1,11 -> 1,12]',
                    openRange: '[1,11 -> 1,12]',
                    closeRange: '[1,18 -> 1,19]',
                },
            ]
        );
        store.dispose();
    }

    function testBasic2() {
        final store = new DisposableStore();
        final doc = new AnnotatedDocument('{ ( [] ¹ ²) [  { } ] () } []');
        final model = createTextModelWithColorizedBracketPairs(store, doc.text);
        assertDeepEquals(
            model.bracketPairs
                .getBracketPairsInRange(doc.range(1, 2))
                .map(bracketPairToJSON)
                .toArray(),
            [
                {
                    level: 0,
                    range: '[1,1 -> 1,2]',
                    openRange: '[1,1 -> 1,2]',
                    closeRange: '[1,23 -> 1,24]',
                },
                {
                    level: 1,
                    range: '[1,3 -> 1,4]',
                    openRange: '[1,3 -> 1,4]',
                    closeRange: '[1,9 -> 1,10]',
                },
            ]
        );
        store.dispose();
    }

    function testBasicEmpty() {
        final store = new DisposableStore();
        final doc = new AnnotatedDocument('¹ ² { ( [] ) [  { } ] () } []');
        final model = createTextModelWithColorizedBracketPairs(store, doc.text);
        assertDeepEquals(
            model.bracketPairs
                .getBracketPairsInRange(doc.range(1, 2))
                .map(bracketPairToJSON)
                .toArray(),
            []
        );
        store.dispose();
    }

    function testBasicAll() {
        final store = new DisposableStore();
        final doc = new AnnotatedDocument('¹ { ( [] ) [  { } ] () } [] ²');
        final model = createTextModelWithColorizedBracketPairs(store, doc.text);
        assertDeepEquals(
            model.bracketPairs
                .getBracketPairsInRange(doc.range(1, 2))
                .map(bracketPairToJSON)
                .toArray(),
            [
                {
                    level: 0,
                    range: '[1,2 -> 1,3]',
                    openRange: '[1,2 -> 1,3]',
                    closeRange: '[1,23 -> 1,24]',
                },
                {
                    level: 1,
                    range: '[1,4 -> 1,5]',
                    openRange: '[1,4 -> 1,5]',
                    closeRange: '[1,9 -> 1,10]',
                },
                {
                    level: 2,
                    range: '[1,6 -> 1,7]',
                    openRange: '[1,6 -> 1,7]',
                    closeRange: '[1,7 -> 1,8]',
                },
                {
                    level: 1,
                    range: '[1,11 -> 1,12]',
                    openRange: '[1,11 -> 1,12]',
                    closeRange: '[1,18 -> 1,19]',
                },
                {
                    level: 2,
                    range: '[1,14 -> 1,15]',
                    openRange: '[1,14 -> 1,15]',
                    closeRange: '[1,16 -> 1,17]',
                },
                {
                    level: 1,
                    range: '[1,20 -> 1,21]',
                    openRange: '[1,20 -> 1,21]',
                    closeRange: '[1,21 -> 1,22]',
                },
                {
                    level: 0,
                    range: '[1,25 -> 1,26]',
                    openRange: '[1,25 -> 1,26]',
                    closeRange: '[1,26 -> 1,27]',
                },
            ]
        );
        store.dispose();
    }

    function testGetBracketsInRange() {
        final store = new DisposableStore();
        final doc = new AnnotatedDocument('¹ { [ ( [ [ (  ) ] ] ) ] } { } ²');
        final model = createTextModelWithColorizedBracketPairs(store, doc.text);
        assertDeepEquals(
            model.bracketPairs
                .getBracketsInRange(doc.range(1, 2))
                .map(b -> ({ level: b.nestingLevel, levelEqualBracketType: b.nestingLevelOfEqualBracketType, range: b.range.toString() }))
                .toArray(),
            [
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,2 -> 1,3]"
                },
                {
                    level: 1,
                    levelEqualBracketType: 0,
                    range: "[1,4 -> 1,5]"
                },
                {
                    level: 2,
                    levelEqualBracketType: 0,
                    range: "[1,6 -> 1,7]"
                },
                {
                    level: 3,
                    levelEqualBracketType: 1,
                    range: "[1,8 -> 1,9]"
                },
                {
                    level: 4,
                    levelEqualBracketType: 2,
                    range: "[1,10 -> 1,11]"
                },
                {
                    level: 5,
                    levelEqualBracketType: 1,
                    range: "[1,12 -> 1,13]"
                },
                {
                    level: 5,
                    levelEqualBracketType: 1,
                    range: "[1,15 -> 1,16]"
                },
                {
                    level: 4,
                    levelEqualBracketType: 2,
                    range: "[1,17 -> 1,18]"
                },
                {
                    level: 3,
                    levelEqualBracketType: 1,
                    range: "[1,19 -> 1,20]"
                },
                {
                    level: 2,
                    levelEqualBracketType: 0,
                    range: "[1,21 -> 1,22]"
                },
                {
                    level: 1,
                    levelEqualBracketType: 0,
                    range: "[1,23 -> 1,24]"
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,25 -> 1,26]"
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,27 -> 1,28]"
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,29 -> 1,30]"
                },
            ]
        );
        store.dispose();
    }

    function testTestErrorBrackets() {
        final store = new DisposableStore();
        final doc = new AnnotatedDocument('¹ { () ] ² ');
        final model = createTextModelWithColorizedBracketPairs(store, doc.text);
        assertDeepEquals(
            model.bracketPairs
                .getBracketsInRange(doc.range(1, 2))
                .map(b -> ({ level: b.nestingLevel, range: b.range.toString(), isInvalid: b.isInvalid }))
                .toArray(),
            [
                {
                    level: 0,
                    isInvalid: true,
                    range: "[1,2 -> 1,3]",
                },
                {
                    level: 1,
                    isInvalid: false,
                    range: "[1,4 -> 1,5]",
                },
                {
                    level: 1,
                    isInvalid: false,
                    range: "[1,5 -> 1,6]",
                },
                {
                    level: 0,
                    isInvalid: true,
                    range: "[1,7 -> 1,8]"
                }
            ]
        );
        store.dispose();
    }

    function testColorizedBracketsVSBrackets() {
        final store = new DisposableStore();
        final doc = new AnnotatedDocument('¹ {} [<()>] <{>} ²');
        final model = createTextModelWithColorizedBracketPairs(store, doc.text);
        assertDeepEquals(
            model.bracketPairs
                .getBracketsInRange(doc.range(1, 2), true)
                .map(b -> ({ level: b.nestingLevel, levelEqualBracketType: b.nestingLevelOfEqualBracketType, range: b.range.toString() }))
                .toArray(),
            [
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,2 -> 1,3]",
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,3 -> 1,4]",
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,5 -> 1,6]",
                },
                {
                    level: 1,
                    levelEqualBracketType: 0,
                    range: "[1,7 -> 1,8]",
                },
                {
                    level: 1,
                    levelEqualBracketType: 0,
                    range: "[1,8 -> 1,9]",
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,10 -> 1,11]",
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,13 -> 1,14]",
                },
                {
                    level: -1,
                    levelEqualBracketType: 0,
                    range: "[1,15 -> 1,16]",
                },
            ]
        );

        assertDeepEquals(
            model.bracketPairs
                .getBracketsInRange(doc.range(1, 2), false)
                .map(b -> ({ level: b.nestingLevel, levelEqualBracketType: b.nestingLevelOfEqualBracketType, range: b.range.toString() }))
                .toArray(),
            [
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,2 -> 1,3]",
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,3 -> 1,4]",
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,5 -> 1,6]",
                },
                {
                    level: 1,
                    levelEqualBracketType: 0,
                    range: "[1,6 -> 1,7]",
                },
                {
                    level: 2,
                    levelEqualBracketType: 0,
                    range: "[1,7 -> 1,8]",
                },
                {
                    level: 2,
                    levelEqualBracketType: 0,
                    range: "[1,8 -> 1,9]",
                },
                {
                    level: 1,
                    levelEqualBracketType: 0,
                    range: "[1,9 -> 1,10]",
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,10 -> 1,11]",
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,12 -> 1,13]",
                },
                {
                    level: 1,
                    levelEqualBracketType: 0,
                    range: "[1,13 -> 1,14]",
                },
                {
                    level: 0,
                    levelEqualBracketType: 0,
                    range: "[1,14 -> 1,15]",
                },
                {
                    level: -1,
                    levelEqualBracketType: 0,
                    range: "[1,15 -> 1,16]",
                },
            ]
        );
        store.dispose();
    }

    static function bracketPairToJSON(pair:BracketPairInfo):Any {
        return {
            level: pair.nestingLevel,
            range: pair.openingBracketRange.toString(),
            openRange: pair.openingBracketRange.toString(),
            closeRange: pair.closingBracketRange != null ? pair.closingBracketRange.toString() : null,
        };
    }

}

private class PositionOffsetTransformer {

    final lineStartOffsetByLineIdx:Array<Int>;

    public function new(text:String) {
        lineStartOffsetByLineIdx = [];
        lineStartOffsetByLineIdx.push(0);
        for (i in 0...text.length) {
            if (text.charAt(i) == '\n') {
                lineStartOffsetByLineIdx.push(i + 1);
            }
        }
    }

    public function getOffset(position:Position):Int {
        return lineStartOffsetByLineIdx[position.lineNumber - 1] + position.column - 1;
    }

    public function getPosition(offset:Int):Position {
        var lineNumber = -1;
        for (i in 0...lineStartOffsetByLineIdx.length) {
            if (lineStartOffsetByLineIdx[i] <= offset) {
                lineNumber = i;
                break;
            }
        }
        return new Position(lineNumber + 1, offset - lineStartOffsetByLineIdx[lineNumber] + 1);
    }

}

private class AnnotatedDocument {

    public final text:String;
    final positions:Map<Int, Position>;

    public function new(src:String) {
        final numbers = ['\u2070', '\u00B9', '\u00B2', '\u00B3', '\u2074', '\u2075', '\u2076', '\u2077', '\u2078', '\u2079'];

        var text = '';
        final offsetPositions = new Map<Int, Int>();
        final offsetPositionsOrder:Array<Int> = [];

        var offset = 0;
        for (i in 0...src.length) {
            final idx = numbers.indexOf(src.charAt(i));
            if (idx >= 0) {
                if (!offsetPositions.exists(idx)) {
                    offsetPositionsOrder.push(idx);
                }
                offsetPositions.set(idx, offset);
            }
            else {
                text += src.charAt(i);
                offset++;
            }
        }

        this.text = text;

        final mapper = new PositionOffsetTransformer(this.text);
        final positions = new Map<Int, Position>();
        for (idx in offsetPositionsOrder) {
            positions.set(idx, mapper.getPosition(offsetPositions.get(idx)));
        }
        this.positions = positions;
    }

    public function range(start:Int, end:Int):Range {
        return Range.fromPositions(positions.get(start), positions.get(end));
    }

}


