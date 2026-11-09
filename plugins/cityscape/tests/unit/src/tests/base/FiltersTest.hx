// Ported from vscode src/vs/base/test/common/filters.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.base;

// Classes of this module:
// - FiltersTest
//
// All the tests are ported. Not ported: the `test.skip` of vscode ('Bad
// completion ranking changes valid variable name to class name when
// pressing "." #187055'), skipped in vscode too.
//
// Notes: the filters of the 'or' test return `true`/`false` in vscode
// (`r as any`); here they return an empty match list or null, which the
// test reads the same way (truthy or not). `matchesWords` (an optional
// third argument) and `anyScore` (no options argument) are wrapped to be
// passed as an `IFilter` and a `FuzzyScorer`, which TypeScript allows
// without a wrapper.

import cityscape.base.common.Filters;
import testing.TestCase;

/**
 * suite('Filters')
 */
class FiltersTest extends TestCase {

    static final matchesWords:IFilter = (word:String, target:String) -> Filters.matchesWords(word, target);

    static final anyScore:FuzzyScorer = (pattern:String, lowPattern:String, patternPos:Int, word:String, lowWord:String, wordPos:Int, ?options:FuzzyScoreOptions) -> {
        return Filters.anyScore(pattern, lowPattern, patternPos, word, lowWord, wordPos);
    };

    static final fuzzyScore:FuzzyScorer = Filters.fuzzyScore;

    static final fuzzyScoreGraceful:FuzzyScorer = Filters.fuzzyScoreGraceful;

    static final fuzzyScoreGracefulAggressive:FuzzyScorer = Filters.fuzzyScoreGracefulAggressive;

    function filterOk(filter:IFilter, word:String, wordToMatchAgainst:String, ?highlights:Array<IMatch>, ?pos:haxe.PosInfos):Void {
        final r = filter(word, wordToMatchAgainst);
        assertTrue(r != null, '${word} didn\'t match ${wordToMatchAgainst}', pos);
        if (highlights != null) {
            assertDeepEquals(highlights, r, word + ' / ' + wordToMatchAgainst, pos);
        }
    }

    function filterNotOk(filter:IFilter, word:String, wordToMatchAgainst:String, ?pos:haxe.PosInfos):Void {
        assertTrue(filter(word, wordToMatchAgainst) == null, '${word} matched ${wordToMatchAgainst}', pos);
    }

    function testOr() {
        var filter:IFilter;
        var counters:Array<Int> = [];
        final newFilter = function(i:Int, r:Bool):IFilter {
            return function(word:String, wordToMatchAgainst:String):Null<Array<IMatch>> {
                counters[i]++;
                return r ? [] : null;
            };
        };

        counters = [0, 0];
        filter = Filters.or(newFilter(0, false), newFilter(1, false));
        filterNotOk(filter, 'anything', 'anything');
        assertDeepEquals([1, 1], counters);

        counters = [0, 0];
        filter = Filters.or(newFilter(0, true), newFilter(1, false));
        filterOk(filter, 'anything', 'anything');
        assertDeepEquals([1, 0], counters);

        counters = [0, 0];
        filter = Filters.or(newFilter(0, true), newFilter(1, true));
        filterOk(filter, 'anything', 'anything');
        assertDeepEquals([1, 0], counters);

        counters = [0, 0];
        filter = Filters.or(newFilter(0, false), newFilter(1, true));
        filterOk(filter, 'anything', 'anything');
        assertDeepEquals([1, 1], counters);
    }

    function testPrefixFilterCaseSensitive() {
        // test('PrefixFilter - case sensitive')
        final matchesStrictPrefix = Filters.matchesStrictPrefix;
        filterNotOk(matchesStrictPrefix, '', '');
        filterOk(matchesStrictPrefix, '', 'anything', []);
        filterOk(matchesStrictPrefix, 'alpha', 'alpha', [{start: 0, end: 5}]);
        filterOk(matchesStrictPrefix, 'alpha', 'alphasomething', [{start: 0, end: 5}]);
        filterNotOk(matchesStrictPrefix, 'alpha', 'alp');
        filterOk(matchesStrictPrefix, 'a', 'alpha', [{start: 0, end: 1}]);
        filterNotOk(matchesStrictPrefix, 'x', 'alpha');
        filterNotOk(matchesStrictPrefix, 'A', 'alpha');
        filterNotOk(matchesStrictPrefix, 'AlPh', 'alPHA');
    }

    function testPrefixFilterIgnoreCase() {
        // test('PrefixFilter - ignore case')
        final matchesPrefix = Filters.matchesPrefix;
        filterOk(matchesPrefix, 'alpha', 'alpha', [{start: 0, end: 5}]);
        filterOk(matchesPrefix, 'alpha', 'alphasomething', [{start: 0, end: 5}]);
        filterNotOk(matchesPrefix, 'alpha', 'alp');
        filterOk(matchesPrefix, 'a', 'alpha', [{start: 0, end: 1}]);
        filterOk(matchesPrefix, 'ä', 'Älpha', [{start: 0, end: 1}]);
        filterNotOk(matchesPrefix, 'x', 'alpha');
        filterOk(matchesPrefix, 'A', 'alpha', [{start: 0, end: 1}]);
        filterOk(matchesPrefix, 'AlPh', 'alPHA', [{start: 0, end: 4}]);
        filterNotOk(matchesPrefix, 'T', '4'); // see https://github.com/microsoft/vscode/issues/22401
    }

    function testCamelCaseFilter() {
        final matchesCamelCase = Filters.matchesCamelCase;
        filterNotOk(matchesCamelCase, '', '');
        filterOk(matchesCamelCase, '', 'anything', []);
        filterOk(matchesCamelCase, 'alpha', 'alpha', [{start: 0, end: 5}]);
        filterOk(matchesCamelCase, 'AlPhA', 'alpha', [{start: 0, end: 5}]);
        filterOk(matchesCamelCase, 'alpha', 'alphasomething', [{start: 0, end: 5}]);
        filterNotOk(matchesCamelCase, 'alpha', 'alp');

        filterOk(matchesCamelCase, 'c', 'CamelCaseRocks', [
            {start: 0, end: 1}
        ]);
        filterOk(matchesCamelCase, 'cc', 'CamelCaseRocks', [
            {start: 0, end: 1},
            {start: 5, end: 6}
        ]);
        filterOk(matchesCamelCase, 'ccr', 'CamelCaseRocks', [
            {start: 0, end: 1},
            {start: 5, end: 6},
            {start: 9, end: 10}
        ]);
        filterOk(matchesCamelCase, 'cacr', 'CamelCaseRocks', [
            {start: 0, end: 2},
            {start: 5, end: 6},
            {start: 9, end: 10}
        ]);
        filterOk(matchesCamelCase, 'cacar', 'CamelCaseRocks', [
            {start: 0, end: 2},
            {start: 5, end: 7},
            {start: 9, end: 10}
        ]);
        filterOk(matchesCamelCase, 'ccarocks', 'CamelCaseRocks', [
            {start: 0, end: 1},
            {start: 5, end: 7},
            {start: 9, end: 14}
        ]);
        filterOk(matchesCamelCase, 'cr', 'CamelCaseRocks', [
            {start: 0, end: 1},
            {start: 9, end: 10}
        ]);
        filterOk(matchesCamelCase, 'fba', 'FooBarAbe', [
            {start: 0, end: 1},
            {start: 3, end: 5}
        ]);
        filterOk(matchesCamelCase, 'fbar', 'FooBarAbe', [
            {start: 0, end: 1},
            {start: 3, end: 6}
        ]);
        filterOk(matchesCamelCase, 'fbara', 'FooBarAbe', [
            {start: 0, end: 1},
            {start: 3, end: 7}
        ]);
        filterOk(matchesCamelCase, 'fbaa', 'FooBarAbe', [
            {start: 0, end: 1},
            {start: 3, end: 5},
            {start: 6, end: 7}
        ]);
        filterOk(matchesCamelCase, 'fbaab', 'FooBarAbe', [
            {start: 0, end: 1},
            {start: 3, end: 5},
            {start: 6, end: 8}
        ]);
        filterOk(matchesCamelCase, 'c2d', 'canvasCreation2D', [
            {start: 0, end: 1},
            {start: 14, end: 16}
        ]);
        filterOk(matchesCamelCase, 'cce', '_canvasCreationEvent', [
            {start: 1, end: 2},
            {start: 7, end: 8},
            {start: 15, end: 16}
        ]);
    }

    function testCamelCaseFilter19256() {
        // test('CamelCaseFilter - #19256')
        assertTrue(Filters.matchesCamelCase('Debug Console', 'Open: Debug Console') != null);
        assertTrue(Filters.matchesCamelCase('Debug console', 'Open: Debug Console') != null);
        assertTrue(Filters.matchesCamelCase('debug console', 'Open: Debug Console') != null);
    }

    function testMatchesContiguousSubString() {
        filterOk(Filters.matchesContiguousSubString, 'cela', 'cancelAnimationFrame()', [
            {start: 3, end: 7}
        ]);
    }

    function testMatchesSubString() {
        filterOk(Filters.matchesSubString, 'cmm', 'cancelAnimationFrame()', [
            {start: 0, end: 1},
            {start: 9, end: 10},
            {start: 18, end: 19}
        ]);
        filterOk(Filters.matchesSubString, 'abc', 'abcabc', [
            {start: 0, end: 3},
        ]);
        filterOk(Filters.matchesSubString, 'abc', 'aaabbbccc', [
            {start: 0, end: 1},
            {start: 3, end: 4},
            {start: 6, end: 7},
        ]);
    }

    function testMatchesSubStringPerformance35346() {
        // test('matchesSubString performance (#35346)')
        filterNotOk(Filters.matchesSubString, 'aaaaaaaaaaaaaaaaaaaax', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    }

    function testWordFilter() {
        filterOk(matchesWords, 'alpha', 'alpha', [{start: 0, end: 5}]);
        filterOk(matchesWords, 'alpha', 'alphasomething', [{start: 0, end: 5}]);
        filterNotOk(matchesWords, 'alpha', 'alp');
        filterOk(matchesWords, 'a', 'alpha', [{start: 0, end: 1}]);
        filterNotOk(matchesWords, 'x', 'alpha');
        filterOk(matchesWords, 'A', 'alpha', [{start: 0, end: 1}]);
        filterOk(matchesWords, 'AlPh', 'alPHA', [{start: 0, end: 4}]);
        assertTrue(Filters.matchesWords('Debug Console', 'Open: Debug Console') != null);

        filterOk(matchesWords, 'gp', 'Git: Pull', [{start: 0, end: 1}, {start: 5, end: 6}]);
        filterOk(matchesWords, 'g p', 'Git: Pull', [{start: 0, end: 1}, {start: 5, end: 6}]);
        filterOk(matchesWords, 'gipu', 'Git: Pull', [{start: 0, end: 2}, {start: 5, end: 7}]);

        filterOk(matchesWords, 'gp', 'Category: Git: Pull', [{start: 10, end: 11}, {start: 15, end: 16}]);
        filterOk(matchesWords, 'g p', 'Category: Git: Pull', [{start: 10, end: 11}, {start: 15, end: 16}]);
        filterOk(matchesWords, 'gipu', 'Category: Git: Pull', [{start: 10, end: 12}, {start: 15, end: 17}]);

        filterNotOk(matchesWords, 'it', 'Git: Pull');
        filterNotOk(matchesWords, 'll', 'Git: Pull');

        filterOk(matchesWords, 'git: プル', 'git: プル', [{start: 0, end: 7}]);
        filterOk(matchesWords, 'git プル', 'git: プル', [{start: 0, end: 3}, {start: 5, end: 7}]);

        filterOk(matchesWords, 'öäk', 'Öhm: Älles Klar', [{start: 0, end: 1}, {start: 5, end: 6}, {start: 11, end: 12}]);

        // Handles issue #123915
        filterOk(matchesWords, 'C++', 'C/C++: command', [{start: 2, end: 5}]);

        // Handles issue #154533
        filterOk(matchesWords, '.', ':', []);
        filterOk(matchesWords, '.', '.', [{start: 0, end: 1}]);

        // assert.ok(matchesWords('gipu', 'Category: Git: Pull', true) === null);
        // assert.deepStrictEqual(matchesWords('pu', 'Category: Git: Pull', true), [{ start: 15, end: 17 }]);

        filterOk(matchesWords, 'bar', 'foo-bar');
        filterOk(matchesWords, 'bar test', 'foo-bar test');
        filterOk(matchesWords, 'fbt', 'foo-bar test');
        filterOk(matchesWords, 'bar test', 'foo-bar (test)');
        filterOk(matchesWords, 'foo bar', 'foo (bar)');

        filterNotOk(matchesWords, 'bar est', 'foo-bar test');
        filterNotOk(matchesWords, 'fo ar', 'foo-bar test');
        filterNotOk(matchesWords, 'for', 'foo-bar test');

        filterOk(matchesWords, 'foo bar', 'foo-bar');
        filterOk(matchesWords, 'foo bar', '123 foo-bar 456');
        filterOk(matchesWords, 'foo-bar', 'foo bar');
        filterOk(matchesWords, 'foo:bar', 'foo:bar');
    }

    function assertMatches(pattern:String, word:String, decoratedWord:Null<String>, filter:FuzzyScorer, ?opts:{?patternPos:Int, ?wordPos:Int, ?firstMatchCanBeWeak:Bool}, ?pos:haxe.PosInfos):Void {
        final patternPos:Int = (opts != null && opts.patternPos != null) ? opts.patternPos : 0;
        final wordPos:Int = (opts != null && opts.wordPos != null) ? opts.wordPos : 0;
        final firstMatchCanBeWeak:Bool = (opts != null && opts.firstMatchCanBeWeak != null) ? opts.firstMatchCanBeWeak : false;
        final r = filter(pattern, pattern.toLowerCase(), patternPos, word, word.toLowerCase(), wordPos, {firstMatchCanBeWeak: firstMatchCanBeWeak, boostFullMatch: true});
        assertTrue((decoratedWord == null) == (r == null), pattern + ' / ' + word + ': ' + (r == null ? 'no match' : 'match'), pos);
        if (r != null) {
            final matches = Filters.createMatches(r);
            var actualWord = '';
            var p = 0;
            for (match in matches) {
                actualWord += word.substring(p, match.start);
                actualWord += '^' + [for (i in match.start...match.end) word.charAt(i)].join('^');
                p = match.end;
            }
            actualWord += word.substring(p);
            assertEquals(decoratedWord, actualWord, pattern + ' / ' + word, pos);
        }
    }

    function testFuzzyScore23215() {
        // test('fuzzyScore, #23215')
        assertMatches('tit', 'win.tit', 'win.^t^i^t', fuzzyScore);
        assertMatches('title', 'win.title', 'win.^t^i^t^l^e', fuzzyScore);
        assertMatches('WordCla', 'WordCharacterClassifier', '^W^o^r^dCharacter^C^l^assifier', fuzzyScore);
        assertMatches('WordCCla', 'WordCharacterClassifier', '^W^o^r^d^Character^C^l^assifier', fuzzyScore);
    }

    function testFuzzyScore23332() {
        // test('fuzzyScore, #23332')
        assertMatches('dete', '"editor.quickSuggestionsDelay"', null, fuzzyScore);
    }

    function testFuzzyScore23190() {
        // test('fuzzyScore, #23190')
        assertMatches('c:\\do', '& \'C:\\Documents and Settings\'', '& \'^C^:^\\^D^ocuments and Settings\'', fuzzyScore);
        assertMatches('c:\\do', '& \'c:\\Documents and Settings\'', '& \'^c^:^\\^D^ocuments and Settings\'', fuzzyScore);
    }

    function testFuzzyScore23581() {
        // test('fuzzyScore, #23581')
        assertMatches('close', 'css.lint.importStatement', '^css.^lint.imp^ort^Stat^ement', fuzzyScore);
        assertMatches('close', 'css.colorDecorators.enable', '^css.co^l^orDecorator^s.^enable', fuzzyScore);
        assertMatches('close', 'workbench.quickOpen.closeOnFocusOut', 'workbench.quickOpen.^c^l^o^s^eOnFocusOut', fuzzyScore);
        assertTopScore(fuzzyScore, 'close', 2, ['css.lint.importStatement', 'css.colorDecorators.enable', 'workbench.quickOpen.closeOnFocusOut']);
    }

    function testFuzzyScore23458() {
        // test('fuzzyScore, #23458')
        assertMatches('highlight', 'editorHoverHighlight', 'editorHover^H^i^g^h^l^i^g^h^t', fuzzyScore);
        assertMatches('hhighlight', 'editorHoverHighlight', 'editor^Hover^H^i^g^h^l^i^g^h^t', fuzzyScore);
        assertMatches('dhhighlight', 'editorHoverHighlight', null, fuzzyScore);
    }

    function testFuzzyScore23746() {
        // test('fuzzyScore, #23746')
        assertMatches('-moz', '-moz-foo', '^-^m^o^z-foo', fuzzyScore);
        assertMatches('moz', '-moz-foo', '-^m^o^z-foo', fuzzyScore);
        assertMatches('moz', '-moz-animation', '-^m^o^z-animation', fuzzyScore);
        assertMatches('moza', '-moz-animation', '-^m^o^z-^animation', fuzzyScore);
    }

    function testFuzzyScore() {
        assertMatches('ab', 'abA', '^a^bA', fuzzyScore);
        assertMatches('ccm', 'cacmelCase', '^ca^c^melCase', fuzzyScore);
        assertMatches('bti', 'the_black_knight', null, fuzzyScore);
        assertMatches('ccm', 'camelCase', null, fuzzyScore);
        assertMatches('cmcm', 'camelCase', null, fuzzyScore);
        assertMatches('BK', 'the_black_knight', 'the_^black_^knight', fuzzyScore);
        assertMatches('KeyboardLayout=', 'KeyboardLayout', null, fuzzyScore);
        assertMatches('LLL', 'SVisualLoggerLogsList', 'SVisual^Logger^Logs^List', fuzzyScore);
        assertMatches('LLLL', 'SVilLoLosLi', null, fuzzyScore);
        assertMatches('LLLL', 'SVisualLoggerLogsList', null, fuzzyScore);
        assertMatches('TEdit', 'TextEdit', '^Text^E^d^i^t', fuzzyScore);
        assertMatches('TEdit', 'TextEditor', '^Text^E^d^i^tor', fuzzyScore);
        assertMatches('TEdit', 'Textedit', '^Text^e^d^i^t', fuzzyScore);
        assertMatches('TEdit', 'text_edit', '^text_^e^d^i^t', fuzzyScore);
        assertMatches('TEditDit', 'TextEditorDecorationType', '^Text^E^d^i^tor^Decorat^ion^Type', fuzzyScore);
        assertMatches('TEdit', 'TextEditorDecorationType', '^Text^E^d^i^torDecorationType', fuzzyScore);
        assertMatches('Tedit', 'TextEdit', '^Text^E^d^i^t', fuzzyScore);
        assertMatches('ba', '?AB?', null, fuzzyScore);
        assertMatches('bkn', 'the_black_knight', 'the_^black_^k^night', fuzzyScore);
        assertMatches('bt', 'the_black_knight', 'the_^black_knigh^t', fuzzyScore);
        assertMatches('ccm', 'camelCasecm', '^camel^Casec^m', fuzzyScore);
        assertMatches('fdm', 'findModel', '^fin^d^Model', fuzzyScore);
        assertMatches('fob', 'foobar', '^f^oo^bar', fuzzyScore);
        assertMatches('fobz', 'foobar', null, fuzzyScore);
        assertMatches('foobar', 'foobar', '^f^o^o^b^a^r', fuzzyScore);
        assertMatches('form', 'editor.formatOnSave', 'editor.^f^o^r^matOnSave', fuzzyScore);
        assertMatches('g p', 'Git: Pull', '^Git:^ ^Pull', fuzzyScore);
        assertMatches('g p', 'Git: Pull', '^Git:^ ^Pull', fuzzyScore);
        assertMatches('gip', 'Git: Pull', '^G^it: ^Pull', fuzzyScore);
        assertMatches('gip', 'Git: Pull', '^G^it: ^Pull', fuzzyScore);
        assertMatches('gp', 'Git: Pull', '^Git: ^Pull', fuzzyScore);
        assertMatches('gp', 'Git_Git_Pull', '^Git_Git_^Pull', fuzzyScore);
        assertMatches('is', 'ImportStatement', '^Import^Statement', fuzzyScore);
        assertMatches('is', 'isValid', '^i^sValid', fuzzyScore);
        assertMatches('lowrd', 'lowWord', '^l^o^wWo^r^d', fuzzyScore);
        assertMatches('myvable', 'myvariable', '^m^y^v^aria^b^l^e', fuzzyScore);
        assertMatches('no', '', null, fuzzyScore);
        assertMatches('no', 'match', null, fuzzyScore);
        assertMatches('ob', 'foobar', null, fuzzyScore);
        assertMatches('sl', 'SVisualLoggerLogsList', '^SVisual^LoggerLogsList', fuzzyScore);
        assertMatches('sllll', 'SVisualLoggerLogsList', '^SVisua^l^Logger^Logs^List', fuzzyScore);
        assertMatches('Three', 'HTMLHRElement', null, fuzzyScore);
        assertMatches('Three', 'Three', '^T^h^r^e^e', fuzzyScore);
        assertMatches('fo', 'barfoo', null, fuzzyScore);
        assertMatches('fo', 'bar_foo', 'bar_^f^oo', fuzzyScore);
        assertMatches('fo', 'bar_Foo', 'bar_^F^oo', fuzzyScore);
        assertMatches('fo', 'bar foo', 'bar ^f^oo', fuzzyScore);
        assertMatches('fo', 'bar.foo', 'bar.^f^oo', fuzzyScore);
        assertMatches('fo', 'bar/foo', 'bar/^f^oo', fuzzyScore);
        assertMatches('fo', 'bar\\foo', 'bar\\^f^oo', fuzzyScore);
    }

    function testFuzzyScoreFirstMatchCanBeWeak() {
        // test('fuzzyScore (first match can be weak)')
        assertMatches('Three', 'HTMLHRElement', 'H^TML^H^R^El^ement', fuzzyScore, {firstMatchCanBeWeak: true});
        assertMatches('tor', 'constructor', 'construc^t^o^r', fuzzyScore, {firstMatchCanBeWeak: true});
        assertMatches('ur', 'constructor', 'constr^ucto^r', fuzzyScore, {firstMatchCanBeWeak: true});
        assertTopScore(fuzzyScore, 'tor', 2, ['constructor', 'Thor', 'cTor']);
    }

    function testFuzzyScoreManyMatches() {
        // test('fuzzyScore, many matches')
        assertMatches(
            'aaaaaa',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            '^a^a^a^a^a^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            fuzzyScore
        );
    }

    function testFreezeWhenFjfjJfjf() {
        // test('Freeze when fjfj -> jfjf, https://github.com/microsoft/vscode/issues/91807')
        assertMatches(
            'jfjfj',
            'fjfjfjfjfjfjfjfjfjfjfj',
            null, fuzzyScore
        );
        assertMatches(
            'jfjfjfjfjfjfjfjfjfj',
            'fjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfj',
            null, fuzzyScore
        );
        assertMatches(
            'jfjfjfjfjfjfjfjfjfjjfjfjfjfjfjfjfjfjfjjfjfjfjfjfjfjfjfjfjjfjfjfjfjfjfjfjfjfjjfjfjfjfjfjfjfjfjfjjfjfjfjfjfjfjfjfjfj',
            'fjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfj',
            null, fuzzyScore
        );
        assertMatches(
            'jfjfjfjfjfjfjfjfjfj',
            'fJfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfj',
            'f^J^f^j^f^j^f^j^f^j^f^j^f^j^f^j^f^j^f^jfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfj', // strong match
            fuzzyScore
        );
        assertMatches(
            'jfjfjfjfjfjfjfjfjfj',
            'fjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfj',
            'f^j^f^j^f^j^f^j^f^j^f^j^f^j^f^j^f^j^f^jfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfjfj', // any match
            fuzzyScore, {firstMatchCanBeWeak: true}
        );
    }

    function testFuzzyScoreIssue26423() {
        // test('fuzzyScore, issue #26423')
        assertMatches('baba', 'abababab', null, fuzzyScore);

        assertMatches(
            'fsfsfs',
            'dsafdsafdsafdsafdsafdsafdsafasdfdsa',
            null,
            fuzzyScore
        );
        assertMatches(
            'fsfsfsfsfsfsfsf',
            'dsafdsafdsafdsafdsafdsafdsafasdfdsafdsafdsafdsafdsfdsafdsfdfdfasdnfdsajfndsjnafjndsajlknfdsa',
            null,
            fuzzyScore
        );
    }

    function testFuzzyIntelliSenseMatchingVsHaxeMetadataCompletion26995() {
        // test('Fuzzy IntelliSense matching vs Haxe metadata completion, #26995')
        assertMatches('f', ':Foo', ':^Foo', fuzzyScore);
        assertMatches('f', ':foo', ':^foo', fuzzyScore);
    }

    function testSeparatorOnlyMatchShouldNotBeWeak79558() {
        // test('Separator only match should not be weak #79558')
        assertMatches('.', 'foo.bar', 'foo^.bar', fuzzyScore);
    }

    function testCannotSetProperty1OfUndefined26511() {
        // test('Cannot set property \'1\' of undefined, #26511')
        final word = [for (i in 0...122) 'a'].join('');
        final pattern = [for (i in 0...119) 'a'].join('');
        Filters.fuzzyScore(pattern, pattern.toLowerCase(), 0, word, word.toLowerCase(), 0);
        assertTrue(true); // must not explode
    }

    function testVscode112NoLongerObeysSortText26096() {
        // test('Vscode 1.12 no longer obeys \'sortText\' in completion items (from language server), #26096')
        assertMatches('  ', '  group', null, fuzzyScore, {patternPos: 2});
        assertMatches('  g', '  group', '  ^group', fuzzyScore, {patternPos: 2});
        assertMatches('g', '  group', '  ^group', fuzzyScore);
        assertMatches('g g', '  groupGroup', null, fuzzyScore);
        assertMatches('g g', '  group Group', '  ^group^ ^Group', fuzzyScore);
        assertMatches(' g g', '  group Group', '  ^group^ ^Group', fuzzyScore, {patternPos: 1});
        assertMatches('zz', 'zzGroup', '^z^zGroup', fuzzyScore);
        assertMatches('zzg', 'zzGroup', '^z^z^Group', fuzzyScore);
        assertMatches('g', 'zzGroup', 'zz^Group', fuzzyScore);
    }

    function testPatternPosIsntWorkingCorrectly79815() {
        // test('patternPos isn\'t working correctly #79815')
        assertMatches(':p'.substr(1), 'prop', '^prop', fuzzyScore, {patternPos: 0});
        assertMatches(':p', 'prop', '^prop', fuzzyScore, {patternPos: 1});
        assertMatches(':p', 'prop', null, fuzzyScore, {patternPos: 2});
        assertMatches(':p', 'proP', 'pro^P', fuzzyScore, {patternPos: 1, wordPos: 1});
        assertMatches(':p', 'aprop', 'a^prop', fuzzyScore, {patternPos: 1, firstMatchCanBeWeak: true});
        assertMatches(':p', 'aprop', null, fuzzyScore, {patternPos: 1, firstMatchCanBeWeak: false});
    }

    function assertTopScore(filter:FuzzyScorer, pattern:String, expected:Int, words:Array<String>, ?pos:haxe.PosInfos):Void {
        var topScore = -(100 * 10);
        var topIdx = 0;
        for (i in 0...words.length) {
            final word = words[i];
            final m = filter(pattern, pattern.toLowerCase(), 0, word, word.toLowerCase(), 0);
            if (m != null) {
                final score = m[0];
                if (score > topScore) {
                    topScore = score;
                    topIdx = i;
                }
            }
        }
        assertEquals(expected, topIdx, '${pattern} -> actual=${words[topIdx]} <> expected=${words[expected]}', pos);
    }

    function testTopScoreFuzzyScore() {
        // test('topScore - fuzzyScore')
        assertTopScore(fuzzyScore, 'cons', 2, ['ArrayBufferConstructor', 'Console', 'console']);
        assertTopScore(fuzzyScore, 'Foo', 1, ['foo', 'Foo', 'foo']);

        // #24904
        assertTopScore(fuzzyScore, 'onMess', 1, ['onmessage', 'onMessage', 'onThisMegaEscape']);

        assertTopScore(fuzzyScore, 'CC', 1, ['camelCase', 'CamelCase']);
        assertTopScore(fuzzyScore, 'cC', 0, ['camelCase', 'CamelCase']);
        // assertTopScore(fuzzyScore, 'cC', 1, 'ccfoo', 'camelCase');
        // assertTopScore(fuzzyScore, 'cC', 1, 'ccfoo', 'camelCase', 'foo-cC-bar');

        // issue #17836
        // assertTopScore(fuzzyScore, 'TEdit', 1, 'TextEditorDecorationType', 'TextEdit', 'TextEditor');
        assertTopScore(fuzzyScore, 'p', 4, ['parse', 'posix', 'pafdsa', 'path', 'p']);
        assertTopScore(fuzzyScore, 'pa', 0, ['parse', 'pafdsa', 'path']);

        // issue #14583
        assertTopScore(fuzzyScore, 'log', 3, ['HTMLOptGroupElement', 'ScrollLogicalPosition', 'SVGFEMorphologyElement', 'log', 'logger']);
        assertTopScore(fuzzyScore, 'e', 2, ['AbstractWorker', 'ActiveXObject', 'else']);

        // issue #14446
        assertTopScore(fuzzyScore, 'workbench.sideb', 1, ['workbench.editor.defaultSideBySideLayout', 'workbench.sideBar.location']);

        // issue #11423
        assertTopScore(fuzzyScore, 'editor.r', 2, ['diffEditor.renderSideBySide', 'editor.overviewRulerlanes', 'editor.renderControlCharacter', 'editor.renderWhitespace']);
        // assertTopScore(fuzzyScore, 'editor.R', 1, 'diffEditor.renderSideBySide', 'editor.overviewRulerlanes', 'editor.renderControlCharacter', 'editor.renderWhitespace');
        // assertTopScore(fuzzyScore, 'Editor.r', 0, 'diffEditor.renderSideBySide', 'editor.overviewRulerlanes', 'editor.renderControlCharacter', 'editor.renderWhitespace');

        assertTopScore(fuzzyScore, '-mo', 1, ['-ms-ime-mode', '-moz-columns']);
        // dupe, issue #14861
        assertTopScore(fuzzyScore, 'convertModelPosition', 0, ['convertModelPositionToViewPosition', 'convertViewToModelPosition']);
        // dupe, issue #14942
        assertTopScore(fuzzyScore, 'is', 0, ['isValidViewletId', 'import statement']);

        assertTopScore(fuzzyScore, 'title', 1, ['files.trimTrailingWhitespace', 'window.title']);

        assertTopScore(fuzzyScore, 'const', 1, ['constructor', 'const', 'cuOnstrul']);
    }

    function testUnexpectedSuggestionScoring28791() {
        // test('Unexpected suggestion scoring, #28791')
        assertTopScore(fuzzyScore, '_lines', 1, ['_lineStarts', '_lines']);
        assertTopScore(fuzzyScore, '_lines', 1, ['_lineS', '_lines']);
        assertTopScore(fuzzyScore, '_lineS', 0, ['_lineS', '_lines']);
    }

    function testHTMLClosingTagProposalFilteredOut38880() {
        // test('HTML closing tag proposal filtered out #38880')
        assertMatches('\t\t<', '\t\t</body>', '^\t^\t^</body>', fuzzyScore, {patternPos: 0});
        assertMatches('\t\t<', '\t\t</body>', '\t\t^</body>', fuzzyScore, {patternPos: 2});
        assertMatches('\t<', '\t</body>', '\t^</body>', fuzzyScore, {patternPos: 1});
    }

    function testFuzzyScoreGraceful() {
        assertMatches('rlut', 'result', null, fuzzyScore);
        assertMatches('rlut', 'result', '^res^u^l^t', fuzzyScoreGraceful);

        assertMatches('cno', 'console', '^co^ns^ole', fuzzyScore);
        assertMatches('cno', 'console', '^co^ns^ole', fuzzyScoreGraceful);
        assertMatches('cno', 'console', '^c^o^nsole', fuzzyScoreGracefulAggressive);
        assertMatches('cno', 'co_new', '^c^o_^new', fuzzyScoreGraceful);
        assertMatches('cno', 'co_new', '^c^o_^new', fuzzyScoreGracefulAggressive);
    }

    function testListHighlightFilterNotAllCharactersFromMatchAreHighlighterd66923() {
        // test('List highlight filter: Not all characters from match are highlighterd #66923')
        assertMatches('foo', 'barbarbarbarbarbarbarbarbarbarbarbarbarbarbarbar_foo', 'barbarbarbarbarbarbarbarbarbarbarbarbarbarbarbar_^f^o^o', fuzzyScore);
    }

    function testAutocompletionIsMatchedAgainstTruncatedFilterTextTo54Characters74133() {
        // test('Autocompletion is matched against truncated filterText to 54 characters #74133')
        assertMatches(
            'foo',
            'ffffffffffffffffffffffffffffbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbar_foo',
            'ffffffffffffffffffffffffffffbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbar_^f^o^o',
            fuzzyScore
        );
        assertMatches(
            'Aoo',
            'Affffffffffffffffffffffffffffbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbar_foo',
            '^Affffffffffffffffffffffffffffbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbar_f^o^o',
            fuzzyScore
        );
        assertMatches(
            'foo',
            'Gffffffffffffffffffffffffffffbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbarbar_foo',
            null,
            fuzzyScore
        );
    }

    function testGoToSymbolWithTheExactMethodNameDoesntWorkAsExpected84787() {
        // test('"Go to Symbol" with the exact method name doesn\'t work as expected #84787')
        final match = Filters.fuzzyScore(':get', ':get', 1, 'get', 'get', 0, {firstMatchCanBeWeak: true, boostFullMatch: true});
        assertTrue(match != null);
    }

    function testWrongHighlightAfterEmoji113404() {
        // test('Wrong highlight after emoji #113404')
        assertMatches('di', '✨div classname=""></div>', '✨^d^iv classname=""></div>', fuzzyScore);
        assertMatches('di', 'adiv classname=""></div>', 'adiv classname=""></^d^iv>', fuzzyScore);
    }

    function testSuggestionIsNotHighlighted85826() {
        // test('Suggestion is not highlighted #85826')
        assertMatches('SemanticTokens', 'SemanticTokensEdits', '^S^e^m^a^n^t^i^c^T^o^k^e^n^sEdits', fuzzyScore);
        assertMatches('SemanticTokens', 'SemanticTokensEdits', '^S^e^m^a^n^t^i^c^T^o^k^e^n^sEdits', fuzzyScoreGracefulAggressive);
    }

    function testIntelliSenseCompletionNotCorrectlyHighlightingTextInFrontOfCursor115250() {
        // test('IntelliSense completion not correctly highlighting text in front of cursor #115250')
        assertMatches('lo', 'log', '^l^og', fuzzyScore);
        assertMatches('.lo', 'log', '^l^og', anyScore);
        assertMatches('.', 'log', 'log', anyScore);
    }

    function testAnyScoreShouldNotRequireAStrongFirstMatch() {
        // test('anyScore should not require a strong first match')
        assertMatches('bar', 'foobAr', 'foo^b^A^r', anyScore);
        assertMatches('bar', 'foobar', 'foo^b^a^r', anyScore);
    }

    function testConfigurableFullMatchBoost() {
        // test('configurable full match boost')
        final prefix = 'create';
        final a = 'createModelServices';
        final b = 'create';

        var aBoost = Filters.fuzzyScore(prefix, prefix, 0, a, a.toLowerCase(), 0, {boostFullMatch: true, firstMatchCanBeWeak: true});
        var bBoost = Filters.fuzzyScore(prefix, prefix, 0, b, b.toLowerCase(), 0, {boostFullMatch: true, firstMatchCanBeWeak: true});
        assertTrue(aBoost != null);
        assertTrue(bBoost != null);
        assertTrue(aBoost[0] < bBoost[0]);

        // also works with wordStart > 0 (https://github.com/microsoft/vscode/issues/187921)
        final wordPrefix = '$(symbol-function) ';
        aBoost = Filters.fuzzyScore(prefix, prefix, 0, '${wordPrefix}${a}', '${wordPrefix}${a}'.toLowerCase(), wordPrefix.length, {boostFullMatch: true, firstMatchCanBeWeak: true});
        bBoost = Filters.fuzzyScore(prefix, prefix, 0, '${wordPrefix}${b}', '${wordPrefix}${b}'.toLowerCase(), wordPrefix.length, {boostFullMatch: true, firstMatchCanBeWeak: true});
        assertTrue(aBoost != null);
        assertTrue(bBoost != null);
        assertTrue(aBoost[0] < bBoost[0]);

        final aScore = Filters.fuzzyScore(prefix, prefix, 0, a, a.toLowerCase(), 0, {boostFullMatch: false, firstMatchCanBeWeak: true});
        final bScore = Filters.fuzzyScore(prefix, prefix, 0, b, b.toLowerCase(), 0, {boostFullMatch: false, firstMatchCanBeWeak: true});
        assertTrue(aScore != null);
        assertTrue(bScore != null);
        assertTrue(aScore[0] == bScore[0]);
    }

    function testUnexpectedSuggestHighlightingIgnoresWholeWordMatchInFavorOfMatchingFirstLetter147423() {
        // test('Unexpected suggest highlighting ignores whole word match in favor of matching first letter#147423')
        assertMatches('i', 'machine/{id}', 'machine/{^id}', fuzzyScore);
        assertMatches('ok', 'obobobf{ok}/user', '^obobobf{o^k}/user', fuzzyScore);
    }

}
