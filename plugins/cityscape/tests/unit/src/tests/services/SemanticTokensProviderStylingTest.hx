// Ported from vscode src/vs/editor/test/common/services/semanticTokensProviderStyling.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.services;

import cityscape.Cityscape;
import cityscape.base.common.Color;
import cityscape.common.EncodedTokenAttributes.MetadataConsts;
import cityscape.common.Languages.SemanticTokens;
import cityscape.common.Languages.SemanticTokensLegend;
import cityscape.common.services.SemanticTokensProviderStyling;
import cityscape.common.tokens.SparseMultilineTokens;
import cityscape.platform.theme.common.Theme.ColorScheme;
import cityscape.platform.theme.common.ThemeService.IColorTheme;
import cityscape.platform.theme.common.ThemeService.ITokenStyle;
import haxe.io.UInt32Array;
import testing.TestCase;

/**
 * The theme of the tests: the foreground of a token type `stN` is N.
 */
private class StubTheme implements IColorTheme {

    public function new() {}

    public var type(get, never):ColorScheme;
    function get_type():ColorScheme {
        return ColorScheme.DARK;
    }

    public var label(get, never):String;
    function get_label():String {
        return 'stub';
    }

    public function getColor(color:String, ?useDefault:Bool):Null<Color> {
        return null;
    }

    public function defines(color:String):Bool {
        return false;
    }

    public function getTokenStyleMetadata(type:String, modifiers:Array<String>, modelLanguage:String):Null<ITokenStyle> {
        return {
            foreground: Std.parseInt(type.substr(2)),
            bold: null,
            underline: null,
            strikethrough: null,
            italic: null
        };
    }

    public var tokenColorMap(get, never):Array<String>;
    function get_tokenColorMap():Array<String> {
        return [];
    }

    public var semanticHighlighting(get, never):Bool;
    function get_semanticHighlighting():Bool {
        return true;
    }

}

/**
 * vscode's suite `ModelService` of semanticTokensProviderStyling.test.ts.
 * The numbers above 2^31 of the data (`4294967294`...) are written as the
 * 32 bit integers with the same bits (`-2`...): Haxe has no unsigned
 * literal, and the styling reads them as JavaScript's `| 0` does.
 */
class SemanticTokensProviderStylingTest extends TestCase {

    var context:Cityscape;

    override public function setup():Void {
        context = new Cityscape();
    }

    function createStyling(languageId:String, legend:SemanticTokensLegend):SemanticTokensProviderStyling {
        context.languageService.registerLanguage({id: languageId});
        final theme = new StubTheme();
        return new SemanticTokensProviderStyling(legend, {getColorTheme: () -> (theme : IColorTheme)}, context.languageService.languageIdCodec);
    }

    static function fg(n:Int):Int {
        return MetadataConsts.SEMANTIC_USE_FOREGROUND | (n << MetadataConsts.FOREGROUND_OFFSET);
    }

    static function toString(result:Array<SparseMultilineTokens>):String {
        return [for (r in result) r.toString()].join(',');
    }

    function testIssue134973InvalidSemanticTokensShouldBeHandledBetter() {
        final languageId = 'java';
        final legend:SemanticTokensLegend = {
            tokenTypes: ['st0', 'st1', 'st2', 'st3', 'st4', 'st5', 'st6', 'st7', 'st8', 'st9', 'st10'],
            tokenModifiers: []
        };
        final styling = createStyling(languageId, legend);
        final badTokens:SemanticTokens = {
            data: UInt32Array.fromArray([
                0, 13, 16, 1, 0,
                1, 2, 6, 2, 0,
                0, 7, 6, 3, 0,
                0, 15, 8, 4, 0,
                0, 17, 1, 5, 0,
                0, 7, 5, 6, 0,
                1, 12, 8, 7, 0,
                0, 19, 5, 8, 0,
                0, 7, 1, 9, 0,
                0, -2 /* 4294967294 */, 5, 10, 0
            ])
        };
        final result = SemanticTokensProviderStyling.toMultilineTokens2(badTokens, styling, languageId);
        final expected = SparseMultilineTokens.create(1, UInt32Array.fromArray([
            0, 13, 29, fg(1),
            1, 2, 8, fg(2),
            1, 9, 15, fg(3),
            1, 24, 32, fg(4),
            1, 41, 42, fg(5),
            1, 48, 53, fg(6),
            2, 12, 20, fg(7),
            2, 31, 36, fg(8),
            2, 38, 39, fg(9),
        ]));
        assertEquals(expected.toString(), toString(result));
    }

    function testIssue148651VSCodeUIProcessCanHangIfASemanticTokenWithNegativeValuesIsReturnedByLanguageService() {
        final languageId = 'dockerfile';
        final legend:SemanticTokensLegend = {
            tokenTypes: ['st0', 'st1', 'st2', 'st3', 'st4', 'st5', 'st6', 'st7', 'st8', 'st9'],
            tokenModifiers: ['stm0', 'stm1', 'stm2']
        };
        final styling = createStyling(languageId, legend);
        final badTokens:SemanticTokens = {
            data: UInt32Array.fromArray([
                0, 0, 3, 0, 0,
                0, 4, 2, 2, 0,
                0, 2, 3, 8, 0,
                0, 3, 1, 9, 0,
                0, 1, 1, 10, 0,
                0, 1, 4, 8, 0,
                0, 4, -4 /* 4294967292 */, 2, 0,
                0, -4 /* 4294967292 */, -2 /* 4294967294 */, 8, 0,
                0, -2 /* 4294967294 */, 1, 9, 0,
                0, 1, 1, 10, 0,
                0, 1, 3, 8, 0,
                0, 3, -5 /* 4294967291 */, 8, 0,
                0, -5 /* 4294967291 */, 1, 9, 0,
                0, 1, 1, 10, 0,
                0, 1, 4, 8, 0
            ])
        };
        final result = SemanticTokensProviderStyling.toMultilineTokens2(badTokens, styling, languageId);
        final expected = SparseMultilineTokens.create(1, UInt32Array.fromArray([
            0, 4, 6, fg(1),
            0, 6, 9, fg(2),
            0, 9, 10, fg(3),
            0, 11, 15, fg(4),
        ]));
        assertEquals(expected.toString(), toString(result));
    }

    function testIssue149130VscodeFreezesBecauseOfBracketPairColorization() {
        final languageId = 'q';
        final legend:SemanticTokensLegend = {
            tokenTypes: ['st0', 'st1', 'st2', 'st3', 'st4', 'st5'],
            tokenModifiers: ['stm0', 'stm1', 'stm2']
        };
        final styling = createStyling(languageId, legend);
        final badTokens:SemanticTokens = {
            data: UInt32Array.fromArray([
                0, 11, 1, 1, 0,
                0, 4, 1, 1, 0,
                0, -7 /* 4294967289 */, 1, 1, 0
            ])
        };
        final result = SemanticTokensProviderStyling.toMultilineTokens2(badTokens, styling, languageId);
        final expected = SparseMultilineTokens.create(1, UInt32Array.fromArray([
            0, 11, 12, fg(1),
            0, 15, 16, fg(1),
        ]));
        assertEquals(expected.toString(), toString(result));
    }

}
