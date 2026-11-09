// Ported from vscode src/vs/editor/test/common/model/model.modes.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.common.Languages;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.NullTokenize;
import haxe.io.UInt32Array;
import testing.TestCase;
import tests.TestTextModel;
import testing.TestTokenizationSupport;

/**
 * Suite 'Editor Model - Model Modes 1'. Each model has its own `Cityscape`
 * context (Monaco registers the tokenizer in the global registry).
 */
class ModelModesTest extends TestCase {

    var calledFor:Array<String> = [];

    var thisModel:TestTextModel;

    var languageRegistration:IDisposable;

    function getAndClear():Array<String> {
        final result = calledFor;
        calledFor = [];
        return result;
    }

    override function setup() {
        final TEXT =
            '1\r\n' +
            '2\n' +
            '3\n' +
            '4\r\n' +
            '5';
        final LANGUAGE_ID = 'modelModeTest1';
        calledFor = [];
        final context = new Cityscape();
        final tokenizationSupport = new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line, hasEOL, state) -> {
                calledFor.push(line.charAt(0));
                return new EncodedTokenizationResult(new UInt32Array(0), state);
            }
        );
        languageRegistration = context.tokenizationRegistry.register(LANGUAGE_ID, tokenizationSupport);
        thisModel = TestTextModel.instantiateTextModel(context, TEXT, LANGUAGE_ID);
    }

    override function teardown() {
        thisModel.dispose();
        languageRegistration.dispose();
        calledFor = [];
    }

    function testModelCallsSyntaxHighlighter1() {
        thisModel.tokenization.forceTokenization(1);
        assertDeepEquals(['1'], getAndClear());
    }

    function testModelCallsSyntaxHighlighter2() {
        thisModel.tokenization.forceTokenization(2);
        assertDeepEquals(['1', '2'], getAndClear());

        thisModel.tokenization.forceTokenization(2);
        assertDeepEquals([], getAndClear());
    }

    function testModelCachesStates() {
        thisModel.tokenization.forceTokenization(1);
        assertDeepEquals(['1'], getAndClear());

        thisModel.tokenization.forceTokenization(2);
        assertDeepEquals(['2'], getAndClear());

        thisModel.tokenization.forceTokenization(3);
        assertDeepEquals(['3'], getAndClear());

        thisModel.tokenization.forceTokenization(4);
        assertDeepEquals(['4'], getAndClear());

        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['5'], getAndClear());

        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals([], getAndClear());
    }

    function testModelInvalidatesStatesForOneLineInsert() {
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['1', '2', '3', '4', '5'], getAndClear());

        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), '-')]);
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['-'], getAndClear());

        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals([], getAndClear());
    }

    function testModelInvalidatesStatesForManyLinesInsert() {
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['1', '2', '3', '4', '5'], getAndClear());

        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), '0\n-\n+')]);
        assertEquals(7, thisModel.getLineCount());
        thisModel.tokenization.forceTokenization(7);
        assertDeepEquals(['0', '-', '+'], getAndClear());

        thisModel.tokenization.forceTokenization(7);
        assertDeepEquals([], getAndClear());
    }

    function testModelInvalidatesStatesForOneNewLine() {
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['1', '2', '3', '4', '5'], getAndClear());

        thisModel.applyEdits([EditOperation.insert(new Position(1, 2), '\n')]);
        thisModel.applyEdits([EditOperation.insert(new Position(2, 1), 'a')]);
        thisModel.tokenization.forceTokenization(6);
        assertDeepEquals(['1', 'a'], getAndClear());
    }

    function testModelInvalidatesStatesForOneLineDelete() {
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['1', '2', '3', '4', '5'], getAndClear());

        thisModel.applyEdits([EditOperation.insert(new Position(1, 2), '-')]);
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['1'], getAndClear());

        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 1, 2))]);
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['-'], getAndClear());

        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals([], getAndClear());
    }

    function testModelInvalidatesStatesForManyLinesDelete() {
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['1', '2', '3', '4', '5'], getAndClear());

        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 3, 1))]);
        thisModel.tokenization.forceTokenization(3);
        assertDeepEquals(['3'], getAndClear());

        thisModel.tokenization.forceTokenization(3);
        assertDeepEquals([], getAndClear());
    }

}

private class ModelState2 implements IState {

    public var prevLineContent:String;

    public function new(prevLineContent:String) {
        this.prevLineContent = prevLineContent;
    }

    public function clone():IState {
        return new ModelState2(prevLineContent);
    }

    public function equals(other:IState):Bool {
        return Std.isOfType(other, ModelState2) && (cast other : ModelState2).prevLineContent == prevLineContent;
    }

}

/**
 * Suite 'Editor Model - Model Modes 2'.
 */
class ModelModes2Test extends TestCase {

    var calledFor:Array<String> = [];

    var thisModel:TestTextModel;

    var languageRegistration:IDisposable;

    function getAndClear():Array<String> {
        final actual = calledFor;
        calledFor = [];
        return actual;
    }

    override function setup() {
        final TEXT =
            'Line1' + '\r\n' +
            'Line2' + '\n' +
            'Line3' + '\n' +
            'Line4' + '\r\n' +
            'Line5';
        final LANGUAGE_ID = 'modelModeTest2';
        calledFor = [];
        final context = new Cityscape();
        final tokenizationSupport = new TestTokenizationSupport(
            () -> new ModelState2(''),
            (line, hasEOL, state) -> {
                calledFor.push(line);
                (cast state : ModelState2).prevLineContent = line;
                return new EncodedTokenizationResult(new UInt32Array(0), state);
            }
        );
        languageRegistration = context.tokenizationRegistry.register(LANGUAGE_ID, tokenizationSupport);
        thisModel = TestTextModel.instantiateTextModel(context, TEXT, LANGUAGE_ID);
    }

    override function teardown() {
        thisModel.dispose();
        languageRegistration.dispose();
    }

    function testGetTokensForInvalidLinesOneTextInsert() {
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['Line1', 'Line2', 'Line3', 'Line4', 'Line5'], getAndClear());
        thisModel.applyEdits([EditOperation.insert(new Position(1, 6), '-')]);
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['Line1-', 'Line2'], getAndClear());
    }

    function testGetTokensForInvalidLinesTwoTextInsert() {
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['Line1', 'Line2', 'Line3', 'Line4', 'Line5'], getAndClear());
        thisModel.applyEdits([
            EditOperation.insert(new Position(1, 6), '-'),
            EditOperation.insert(new Position(3, 6), '-')
        ]);

        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['Line1-', 'Line2', 'Line3-', 'Line4'], getAndClear());
    }

    function testGetTokensForInvalidLinesOneMultiLineTextInsertOneSmallTextInsert() {
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['Line1', 'Line2', 'Line3', 'Line4', 'Line5'], getAndClear());
        thisModel.applyEdits([EditOperation.insert(new Position(1, 6), '\nNew line\nAnother new line')]);
        thisModel.applyEdits([EditOperation.insert(new Position(5, 6), '-')]);
        thisModel.tokenization.forceTokenization(7);
        assertDeepEquals(['Line1', 'New line', 'Another new line', 'Line2', 'Line3-', 'Line4'], getAndClear());
    }

    function testGetTokensForInvalidLinesOneDeleteText() {
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['Line1', 'Line2', 'Line3', 'Line4', 'Line5'], getAndClear());
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 1, 5))]);
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['1', 'Line2'], getAndClear());
    }

    function testGetTokensForInvalidLinesOneLineDeleteText() {
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['Line1', 'Line2', 'Line3', 'Line4', 'Line5'], getAndClear());
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 2, 1))]);
        thisModel.tokenization.forceTokenization(4);
        assertDeepEquals(['Line2'], getAndClear());
    }

    function testGetTokensForInvalidLinesMultipleLinesDeleteText() {
        thisModel.tokenization.forceTokenization(5);
        assertDeepEquals(['Line1', 'Line2', 'Line3', 'Line4', 'Line5'], getAndClear());
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 3, 3))]);
        thisModel.tokenization.forceTokenization(3);
        assertDeepEquals(['ne3', 'Line4'], getAndClear());
    }

}
