// Ported from vscode src/vs/editor/test/common/modes/supports/electricCharacter.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.modes.supports;

import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.languages.supports.ElectricCharacter;
import cityscape.common.languages.supports.RichEditBrackets;
import haxe.PosInfos;
import testing.ModesTestUtils;
import testing.TestCase;

/**
 * suite('Editor Modes - Auto Indentation')
 */
class ElectricCharacterTest extends TestCase {

    static inline final fakeLanguageId = 'test';

    function _testOnElectricCharacter(electricCharacterSupport:BracketElectricCharacterSupport, line:Array<TokenText>, character:String, offset:Int):Null<IElectricAction> {
        return electricCharacterSupport.onElectricCharacter(character, ModesTestUtils.createFakeScopedLineTokens(line), offset);
    }

    function doesNothing(electricCharacterSupport:BracketElectricCharacterSupport, line:Array<TokenText>, character:String, offset:Int, ?pos:PosInfos):Void {
        final actual = _testOnElectricCharacter(electricCharacterSupport, line, character, offset);
        assertDeepEquals(null, actual, null, pos);
    }

    function matchBracket(electricCharacterSupport:BracketElectricCharacterSupport, line:Array<TokenText>, character:String, offset:Int, matchOpenBracket:String, ?pos:PosInfos):Void {
        final actual = _testOnElectricCharacter(electricCharacterSupport, line, character, offset);
        assertDeepEquals({matchOpenBracket: matchOpenBracket}, actual, null, pos);
    }

    function testGetElectricCharactersUsesAllSourcesAndDedups() {
        final sup = new BracketElectricCharacterSupport(
            new RichEditBrackets(fakeLanguageId, [
                ['{', '}'],
                ['(', ')']
            ])
        );

        assertDeepEquals(sup.getElectricCharacters(), ['}', ')']);
    }

    function testMatchOpenBracket() {
        final sup = new BracketElectricCharacterSupport(
            new RichEditBrackets(fakeLanguageId, [
                ['{', '}'],
                ['(', ')']
            ])
        );

        doesNothing(sup, [{text: '\t{', type: StandardTokenType.Other}], '\t', 1);
        doesNothing(sup, [{text: '\t{', type: StandardTokenType.Other}], '\t', 2);
        doesNothing(sup, [{text: '\t\t', type: StandardTokenType.Other}], '{', 3);

        doesNothing(sup, [{text: '\t}', type: StandardTokenType.Other}], '\t', 1);
        doesNothing(sup, [{text: '\t}', type: StandardTokenType.Other}], '\t', 2);
        matchBracket(sup, [{text: '\t\t', type: StandardTokenType.Other}], '}', 3, '}');
    }

}
