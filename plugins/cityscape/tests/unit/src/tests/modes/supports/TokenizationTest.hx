// Ported from vscode src/vs/editor/test/common/modes/supports/tokenization.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.modes.supports;

import cityscape.base.common.Color;
import cityscape.common.EncodedTokenAttributes.FontStyle;
import cityscape.common.languages.supports.Tokenization;
import haxe.PosInfos;
import testing.TestCase;

/**
 * suite('Token theme matching'), suite('Token theme parsing'),
 * suite('Token theme resolving')
 *
 * `assert.deepStrictEqual` on the classes compares their fields (helpers
 * below): rules by font style, colors and metadata, trie elements
 * recursively (children compared as maps), color maps color by color.
 */
class TokenizationTest extends TestCase {

    static function ruleToString(r:ThemeTrieElementRule):String {
        return @:privateAccess ('{fontStyle: ${r._fontStyle}, foreground: ${r._foreground}, background: ${r._background}, metadata: ${r.metadata}}');
    }

    static function rulesEqual(a:ThemeTrieElementRule, b:ThemeTrieElementRule):Bool {
        return @:privateAccess (a._fontStyle == b._fontStyle && a._foreground == b._foreground && a._background == b._background && a.metadata == b.metadata);
    }

    function assertRule(actual:ThemeTrieElementRule, expected:ThemeTrieElementRule, ?message:String, ?pos:PosInfos) {
        assertTrue(rulesEqual(actual, expected), (message != null ? message + ': ' : '') + 'expected ' + ruleToString(expected) + ' but got ' + ruleToString(actual), pos);
    }

    static function diffElements(a:ExternalThemeTrieElement, b:ExternalThemeTrieElement, path:String):Null<String> {
        if (!rulesEqual(a.mainRule, b.mainRule)) {
            return path + ': ' + ruleToString(a.mainRule) + ' != ' + ruleToString(b.mainRule);
        }
        final keysA = [for (k in a.children.keys()) k];
        final keysB = [for (k in b.children.keys()) k];
        keysA.sort(Reflect.compare);
        keysB.sort(Reflect.compare);
        if (keysA.join(',') != keysB.join(',')) {
            return path + ': children [' + keysA.join(', ') + '] != [' + keysB.join(', ') + ']';
        }
        for (k in keysA) {
            final d = diffElements(a.children.get(k), b.children.get(k), path + '.' + k);
            if (d != null) {
                return d;
            }
        }
        return null;
    }

    function assertElement(actual:ExternalThemeTrieElement, expected:ExternalThemeTrieElement, ?pos:PosInfos) {
        final d = diffElements(actual, expected, 'root');
        assertTrue(d == null, d, pos);
    }

    static function colorMapToString(colorMap:Array<Color>):String {
        return [for (c in colorMap) c == null ? 'undefined' : ColorFormatCSS.formatHexA(c)].join(',');
    }

    function assertColorMap(actual:Array<Color>, expected:Array<Color>, ?pos:PosInfos) {
        assertEquals(colorMapToString(expected), colorMapToString(actual), null, pos);
    }

    function assertParsedRules(actual:Array<ParsedTokenThemeRule>, expected:Array<ParsedTokenThemeRule>, ?pos:PosInfos) {
        final toString = (rules:Array<ParsedTokenThemeRule>) -> [for (r in rules) '(${r.token}, ${r.index}, ${r.fontStyle}, ${r.foreground}, ${r.background})'].join('\n');
        assertEquals(toString(expected), toString(actual), null, pos);
    }

    // suite('Token theme matching')

    function testGivesHigherPriorityToDeeperMatches() {
        final theme = TokenTheme.createFromRawTokenTheme([
            { token: '', foreground: '100000', background: '200000' },
            { token: 'punctuation.definition.string.begin.html', foreground: '300000' },
            { token: 'punctuation.definition.string', foreground: '400000' },
        ], []);

        final colorMap = new ColorMap();
        colorMap.getId('100000');
        final _B = colorMap.getId('200000');
        colorMap.getId('400000');
        final _D = colorMap.getId('300000');

        final actual = theme._match('punctuation.definition.string.begin.html');

        assertRule(actual, new ThemeTrieElementRule(FontStyle.None, _D, _B));
    }

    function testCanMatch() {
        final theme = TokenTheme.createFromRawTokenTheme([
            { token: '', foreground: 'F8F8F2', background: '272822' },
            { token: 'source', background: '100000' },
            { token: 'something', background: '100000' },
            { token: 'bar', background: '200000' },
            { token: 'baz', background: '200000' },
            { token: 'bar', fontStyle: 'bold' },
            { token: 'constant', fontStyle: 'italic', foreground: '300000' },
            { token: 'constant.numeric', foreground: '400000' },
            { token: 'constant.numeric.hex', fontStyle: 'bold' },
            { token: 'constant.numeric.oct', fontStyle: 'bold italic underline' },
            { token: 'constant.numeric.bin', fontStyle: 'bold strikethrough' },
            { token: 'constant.numeric.dec', fontStyle: '', foreground: '500000' },
            { token: 'storage.object.bar', fontStyle: '', foreground: '600000' },
        ], []);

        final colorMap = new ColorMap();
        final _A = colorMap.getId('F8F8F2');
        final _B = colorMap.getId('272822');
        final _C = colorMap.getId('200000');
        final _D = colorMap.getId('300000');
        final _E = colorMap.getId('400000');
        final _F = colorMap.getId('500000');
        final _G = colorMap.getId('100000');
        final _H = colorMap.getId('600000');

        function assertMatch(scopeName:String, expected:ThemeTrieElementRule, ?pos:PosInfos):Void {
            final actual = theme._match(scopeName);
            assertRule(actual, expected, 'when matching <<' + scopeName + '>>', pos);
        }

        function assertSimpleMatch(scopeName:String, fontStyle:FontStyle, foreground:Int, background:Int, ?pos:PosInfos):Void {
            assertMatch(scopeName, new ThemeTrieElementRule(fontStyle, foreground, background), pos);
        }

        function assertNoMatch(scopeName:String, ?pos:PosInfos):Void {
            assertMatch(scopeName, new ThemeTrieElementRule(FontStyle.None, _A, _B), pos);
        }

        // matches defaults
        assertNoMatch('');
        assertNoMatch('bazz');
        assertNoMatch('asdfg');

        // matches source
        assertSimpleMatch('source', FontStyle.None, _A, _G);
        assertSimpleMatch('source.ts', FontStyle.None, _A, _G);
        assertSimpleMatch('source.tss', FontStyle.None, _A, _G);

        // matches something
        assertSimpleMatch('something', FontStyle.None, _A, _G);
        assertSimpleMatch('something.ts', FontStyle.None, _A, _G);
        assertSimpleMatch('something.tss', FontStyle.None, _A, _G);

        // matches baz
        assertSimpleMatch('baz', FontStyle.None, _A, _C);
        assertSimpleMatch('baz.ts', FontStyle.None, _A, _C);
        assertSimpleMatch('baz.tss', FontStyle.None, _A, _C);

        // matches constant
        assertSimpleMatch('constant', FontStyle.Italic, _D, _B);
        assertSimpleMatch('constant.string', FontStyle.Italic, _D, _B);
        assertSimpleMatch('constant.hex', FontStyle.Italic, _D, _B);

        // matches constant.numeric
        assertSimpleMatch('constant.numeric', FontStyle.Italic, _E, _B);
        assertSimpleMatch('constant.numeric.baz', FontStyle.Italic, _E, _B);

        // matches constant.numeric.hex
        assertSimpleMatch('constant.numeric.hex', FontStyle.Bold, _E, _B);
        assertSimpleMatch('constant.numeric.hex.baz', FontStyle.Bold, _E, _B);

        // matches constant.numeric.oct
        assertSimpleMatch('constant.numeric.oct', FontStyle.Bold | FontStyle.Italic | FontStyle.Underline, _E, _B);
        assertSimpleMatch('constant.numeric.oct.baz', FontStyle.Bold | FontStyle.Italic | FontStyle.Underline, _E, _B);

        // matches constant.numeric.bin
        assertSimpleMatch('constant.numeric.bin', FontStyle.Bold | FontStyle.Strikethrough, _E, _B);
        assertSimpleMatch('constant.numeric.bin.baz', FontStyle.Bold | FontStyle.Strikethrough, _E, _B);

        // matches constant.numeric.dec
        assertSimpleMatch('constant.numeric.dec', FontStyle.None, _F, _B);
        assertSimpleMatch('constant.numeric.dec.baz', FontStyle.None, _F, _B);

        // matches storage.object.bar
        assertSimpleMatch('storage.object.bar', FontStyle.None, _H, _B);
        assertSimpleMatch('storage.object.bar.baz', FontStyle.None, _H, _B);

        // does not match storage.object.bar
        assertSimpleMatch('storage.object.bart', FontStyle.None, _A, _B);
        assertSimpleMatch('storage.object', FontStyle.None, _A, _B);
        assertSimpleMatch('storage', FontStyle.None, _A, _B);

        assertSimpleMatch('bar', FontStyle.Bold, _A, _C);
    }

    // suite('Token theme parsing')

    function testCanParse() {

        final actual = Tokenization.parseTokenTheme([
            { token: '', foreground: 'F8F8F2', background: '272822' },
            { token: 'source', background: '100000' },
            { token: 'something', background: '100000' },
            { token: 'bar', background: '010000' },
            { token: 'baz', background: '010000' },
            { token: 'bar', fontStyle: 'bold' },
            { token: 'constant', fontStyle: 'italic', foreground: 'ff0000' },
            { token: 'constant.numeric', foreground: '00ff00' },
            { token: 'constant.numeric.hex', fontStyle: 'bold' },
            { token: 'constant.numeric.oct', fontStyle: 'bold italic underline' },
            { token: 'constant.numeric.dec', fontStyle: '', foreground: '0000ff' },
        ]);

        final expected = [
            new ParsedTokenThemeRule('', 0, FontStyle.NotSet, 'F8F8F2', '272822'),
            new ParsedTokenThemeRule('source', 1, FontStyle.NotSet, null, '100000'),
            new ParsedTokenThemeRule('something', 2, FontStyle.NotSet, null, '100000'),
            new ParsedTokenThemeRule('bar', 3, FontStyle.NotSet, null, '010000'),
            new ParsedTokenThemeRule('baz', 4, FontStyle.NotSet, null, '010000'),
            new ParsedTokenThemeRule('bar', 5, FontStyle.Bold, null, null),
            new ParsedTokenThemeRule('constant', 6, FontStyle.Italic, 'ff0000', null),
            new ParsedTokenThemeRule('constant.numeric', 7, FontStyle.NotSet, '00ff00', null),
            new ParsedTokenThemeRule('constant.numeric.hex', 8, FontStyle.Bold, null, null),
            new ParsedTokenThemeRule('constant.numeric.oct', 9, FontStyle.Bold | FontStyle.Italic | FontStyle.Underline, null, null),
            new ParsedTokenThemeRule('constant.numeric.dec', 10, FontStyle.None, '0000ff', null),
        ];

        assertParsedRules(actual, expected);
    }

    // suite('Token theme resolving')

    function testStrcmpWorks() {
        final actual = ['bar', 'z', 'zu', 'a', 'ab', ''];
        actual.sort(Tokenization.strcmp);

        final expected = ['', 'a', 'ab', 'bar', 'z', 'zu'];
        assertDeepEquals(expected, actual);
    }

    function testAlwaysHasDefaults() {
        final actual = TokenTheme.createFromParsedTokenTheme([], []);
        final colorMap = new ColorMap();
        final _A = colorMap.getId('000000');
        final _B = colorMap.getId('ffffff');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
        assertElement(actual.getThemeTrieElement(), new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.None, _A, _B)));
    }

    function testRespectsIncomingDefaults1() {
        final actual = TokenTheme.createFromParsedTokenTheme([
            new ParsedTokenThemeRule('', -1, FontStyle.NotSet, null, null)
        ], []);
        final colorMap = new ColorMap();
        final _A = colorMap.getId('000000');
        final _B = colorMap.getId('ffffff');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
        assertElement(actual.getThemeTrieElement(), new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.None, _A, _B)));
    }

    function testRespectsIncomingDefaults2() {
        final actual = TokenTheme.createFromParsedTokenTheme([
            new ParsedTokenThemeRule('', -1, FontStyle.None, null, null)
        ], []);
        final colorMap = new ColorMap();
        final _A = colorMap.getId('000000');
        final _B = colorMap.getId('ffffff');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
        assertElement(actual.getThemeTrieElement(), new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.None, _A, _B)));
    }

    function testRespectsIncomingDefaults3() {
        final actual = TokenTheme.createFromParsedTokenTheme([
            new ParsedTokenThemeRule('', -1, FontStyle.Bold, null, null)
        ], []);
        final colorMap = new ColorMap();
        final _A = colorMap.getId('000000');
        final _B = colorMap.getId('ffffff');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
        assertElement(actual.getThemeTrieElement(), new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.Bold, _A, _B)));
    }

    function testRespectsIncomingDefaults4() {
        final actual = TokenTheme.createFromParsedTokenTheme([
            new ParsedTokenThemeRule('', -1, FontStyle.NotSet, 'ff0000', null)
        ], []);
        final colorMap = new ColorMap();
        final _A = colorMap.getId('ff0000');
        final _B = colorMap.getId('ffffff');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
        assertElement(actual.getThemeTrieElement(), new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.None, _A, _B)));
    }

    function testRespectsIncomingDefaults5() {
        final actual = TokenTheme.createFromParsedTokenTheme([
            new ParsedTokenThemeRule('', -1, FontStyle.NotSet, null, 'ff0000')
        ], []);
        final colorMap = new ColorMap();
        final _A = colorMap.getId('000000');
        final _B = colorMap.getId('ff0000');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
        assertElement(actual.getThemeTrieElement(), new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.None, _A, _B)));
    }

    function testCanMergeIncomingDefaults() {
        final actual = TokenTheme.createFromParsedTokenTheme([
            new ParsedTokenThemeRule('', -1, FontStyle.NotSet, null, 'ff0000'),
            new ParsedTokenThemeRule('', -1, FontStyle.NotSet, '00ff00', null),
            new ParsedTokenThemeRule('', -1, FontStyle.Bold, null, null),
        ], []);
        final colorMap = new ColorMap();
        final _A = colorMap.getId('00ff00');
        final _B = colorMap.getId('ff0000');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
        assertElement(actual.getThemeTrieElement(), new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.Bold, _A, _B)));
    }

    function testDefaultsAreInherited() {
        final actual = TokenTheme.createFromParsedTokenTheme([
            new ParsedTokenThemeRule('', -1, FontStyle.NotSet, 'F8F8F2', '272822'),
            new ParsedTokenThemeRule('var', -1, FontStyle.NotSet, 'ff0000', null)
        ], []);
        final colorMap = new ColorMap();
        final _A = colorMap.getId('F8F8F2');
        final _B = colorMap.getId('272822');
        final _C = colorMap.getId('ff0000');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
        final root = new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.None, _A, _B), {
            'var': new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.None, _C, _B))
        });
        assertElement(actual.getThemeTrieElement(), root);
    }

    function testSameRulesGetMerged() {
        final actual = TokenTheme.createFromParsedTokenTheme([
            new ParsedTokenThemeRule('', -1, FontStyle.NotSet, 'F8F8F2', '272822'),
            new ParsedTokenThemeRule('var', 1, FontStyle.Bold, null, null),
            new ParsedTokenThemeRule('var', 0, FontStyle.NotSet, 'ff0000', null),
        ], []);
        final colorMap = new ColorMap();
        final _A = colorMap.getId('F8F8F2');
        final _B = colorMap.getId('272822');
        final _C = colorMap.getId('ff0000');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
        final root = new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.None, _A, _B), {
            'var': new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.Bold, _C, _B))
        });
        assertElement(actual.getThemeTrieElement(), root);
    }

    function testRulesAreInherited1() {
        final actual = TokenTheme.createFromParsedTokenTheme([
            new ParsedTokenThemeRule('', -1, FontStyle.NotSet, 'F8F8F2', '272822'),
            new ParsedTokenThemeRule('var', -1, FontStyle.Bold, 'ff0000', null),
            new ParsedTokenThemeRule('var.identifier', -1, FontStyle.NotSet, '00ff00', null),
        ], []);
        final colorMap = new ColorMap();
        final _A = colorMap.getId('F8F8F2');
        final _B = colorMap.getId('272822');
        final _C = colorMap.getId('ff0000');
        final _D = colorMap.getId('00ff00');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
        final root = new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.None, _A, _B), {
            'var': new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.Bold, _C, _B), {
                'identifier': new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.Bold, _D, _B))
            })
        });
        assertElement(actual.getThemeTrieElement(), root);
    }

    function testRulesAreInherited2() {
        final actual = TokenTheme.createFromParsedTokenTheme([
            new ParsedTokenThemeRule('', -1, FontStyle.NotSet, 'F8F8F2', '272822'),
            new ParsedTokenThemeRule('var', -1, FontStyle.Bold, 'ff0000', null),
            new ParsedTokenThemeRule('var.identifier', -1, FontStyle.NotSet, '00ff00', null),
            new ParsedTokenThemeRule('constant', 4, FontStyle.Italic, '100000', null),
            new ParsedTokenThemeRule('constant.numeric', 5, FontStyle.NotSet, '200000', null),
            new ParsedTokenThemeRule('constant.numeric.hex', 6, FontStyle.Bold, null, null),
            new ParsedTokenThemeRule('constant.numeric.oct', 7, FontStyle.Bold | FontStyle.Italic | FontStyle.Underline, null, null),
            new ParsedTokenThemeRule('constant.numeric.dec', 8, FontStyle.None, '300000', null),
        ], []);
        final colorMap = new ColorMap();
        final _A = colorMap.getId('F8F8F2');
        final _B = colorMap.getId('272822');
        final _C = colorMap.getId('100000');
        final _D = colorMap.getId('200000');
        final _E = colorMap.getId('300000');
        final _F = colorMap.getId('ff0000');
        final _G = colorMap.getId('00ff00');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
        final root = new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.None, _A, _B), {
            'var': new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.Bold, _F, _B), {
                'identifier': new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.Bold, _G, _B))
            }),
            'constant': new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.Italic, _C, _B), {
                'numeric': new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.Italic, _D, _B), {
                    'hex': new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.Bold, _D, _B)),
                    'oct': new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.Bold | FontStyle.Italic | FontStyle.Underline, _D, _B)),
                    'dec': new ExternalThemeTrieElement(new ThemeTrieElementRule(FontStyle.None, _E, _B)),
                })
            })
        });
        assertElement(actual.getThemeTrieElement(), root);
    }

    function testCustomColorsAreFirstInColorMap() {
        final actual = TokenTheme.createFromParsedTokenTheme([
            new ParsedTokenThemeRule('var', -1, FontStyle.NotSet, 'F8F8F2', null)
        ], [
            '000000', 'FFFFFF', '0F0F0F'
        ]);
        final colorMap = new ColorMap();
        colorMap.getId('000000');
        colorMap.getId('FFFFFF');
        colorMap.getId('0F0F0F');
        colorMap.getId('F8F8F2');
        assertColorMap(actual.getColorMap(), colorMap.getColorMap());
    }

}
