// Ported from vscode src/vs/editor/test/common/model/textModelSearch.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.base.common.RegExp;
import cityscape.common.Model;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.WordCharacterClassifier;
import cityscape.common.core.WordHelper;
import cityscape.common.model.TextModel;
import cityscape.common.model.TextModelSearch;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

// Classes of this module:
//   TextModelSearchTest

/**
 * suite('TextModelSearch')
 *
 * The suite constant `usualWordSeparators` is created locally in the two tests that use it.
 */
class TextModelSearchTest extends TestCase {

    function assertFindMatch(actual:Null<FindMatch>, expectedRange:Range, ?expectedMatches:Array<String>):Void {
        assertDeepEquals(actual, new FindMatch(expectedRange, expectedMatches));
    }

    function _assertFindMatches(model:TextModel, searchParams:SearchParams, expectedMatches:Array<FindMatch>):Void {
        final actual = TextModelSearch.findMatches(model, searchParams, model.getFullModelRange(), false, 1000);
        assertDeepEquals(actual, expectedMatches, 'findMatches OK');

        // test `findNextMatch`
        var startPos = new Position(1, 1);
        var match = TextModelSearch.findNextMatch(model, searchParams, startPos, false);
        assertDeepEquals(match, expectedMatches[0], 'findNextMatch ${startPos}');
        for (expectedMatch in expectedMatches) {
            startPos = expectedMatch.range.getStartPosition();
            match = TextModelSearch.findNextMatch(model, searchParams, startPos, false);
            assertDeepEquals(match, expectedMatch, 'findNextMatch ${startPos}');
        }

        // test `findPrevMatch`
        startPos = new Position(model.getLineCount(), model.getLineMaxColumn(model.getLineCount()));
        match = TextModelSearch.findPreviousMatch(model, searchParams, startPos, false);
        assertDeepEquals(match, expectedMatches[expectedMatches.length - 1], 'findPrevMatch ${startPos}');
        for (expectedMatch in expectedMatches) {
            startPos = expectedMatch.range.getEndPosition();
            match = TextModelSearch.findPreviousMatch(model, searchParams, startPos, false);
            assertDeepEquals(match, expectedMatch, 'findPrevMatch ${startPos}');
        }
    }

    function assertFindMatches(text:String, searchString:String, isRegex:Bool, matchCase:Bool, wordSeparators:Null<String>, _expected:Array<Array<Int>>):Void {
        final expectedRanges = _expected.map(entry -> new Range(entry[0], entry[1], entry[2], entry[3]));
        final expectedMatches = expectedRanges.map(entry -> new FindMatch(entry, null));
        final searchParams = new SearchParams(searchString, isRegex, matchCase, wordSeparators);

        final model = createTextModel(text);
        _assertFindMatches(model, searchParams, expectedMatches);
        model.dispose();


        final model2 = createTextModel(text);
        model2.setEOL(EndOfLineSequence.CRLF);
        _assertFindMatches(model2, searchParams, expectedMatches);
        model2.dispose();
    }

    static final regularText = [
        'This is some foo - bar text which contains foo and bar - as in Barcelona.',
        'Now it begins a word fooBar and now it is caps Foo-isn\'t this great?',
        'And here\'s a dull line with nothing interesting in it',
        'It is also interesting if it\'s part of a word like amazingFooBar',
        'Again nothing interesting here'
    ];

    function assertParseSearchResult(searchString:String, isRegex:Bool, matchCase:Bool, wordSeparators:Null<String>, expected:Null<SearchData>):Void {
        final searchParams = new SearchParams(searchString, isRegex, matchCase, wordSeparators);
        final actual = searchParams.parseSearchRequest();

        if (expected == null) {
            assertTrue(actual == null);
        }
        else {
            assertDeepEquals(actual.regex, expected.regex);
            assertDeepEquals(actual.simpleSearch, expected.simpleSearch);
            if (wordSeparators != null && wordSeparators.length > 0) {
                assertTrue(actual.wordSeparators != null);
            }
            else {
                assertTrue(actual.wordSeparators == null);
            }
        }
    }

    // test('Simple find')
    function testSimpleFind() {
        assertFindMatches(
            regularText.join('\n'),
            'foo', false, false, null,
            [
                [1, 14, 1, 17],
                [1, 44, 1, 47],
                [2, 22, 2, 25],
                [2, 48, 2, 51],
                [4, 59, 4, 62]
            ]
        );
    }

    // test('Case sensitive find')
    function testCaseSensitiveFind() {
        assertFindMatches(
            regularText.join('\n'),
            'foo', false, true, null,
            [
                [1, 14, 1, 17],
                [1, 44, 1, 47],
                [2, 22, 2, 25]
            ]
        );
    }

    // test('Whole words find')
    function testWholeWordsFind() {
        assertFindMatches(
            regularText.join('\n'),
            'foo', false, false, WordHelper.USUAL_WORD_SEPARATORS,
            [
                [1, 14, 1, 17],
                [1, 44, 1, 47],
                [2, 48, 2, 51]
            ]
        );
    }

    // test('/^/ find')
    function testFind() {
        assertFindMatches(
            regularText.join('\n'),
            '^', true, false, null,
            [
                [1, 1, 1, 1],
                [2, 1, 2, 1],
                [3, 1, 3, 1],
                [4, 1, 4, 1],
                [5, 1, 5, 1]
            ]
        );
    }

    // test('/$/ find')
    function testFind2() {
        assertFindMatches(
            regularText.join('\n'),
            '$$', true, false, null,
            [
                [1, 74, 1, 74],
                [2, 69, 2, 69],
                [3, 54, 3, 54],
                [4, 65, 4, 65],
                [5, 31, 5, 31]
            ]
        );
    }

    // test('/.*/ find')
    function testFind3() {
        assertFindMatches(
            regularText.join('\n'),
            '.*', true, false, null,
            [
                [1, 1, 1, 74],
                [2, 1, 2, 69],
                [3, 1, 3, 54],
                [4, 1, 4, 65],
                [5, 1, 5, 31]
            ]
        );
    }

    // test('/^$/ find')
    function testFind4() {
        assertFindMatches(
            [
                'This is some foo - bar text which contains foo and bar - as in Barcelona.',
                '',
                'And here\'s a dull line with nothing interesting in it',
                '',
                'Again nothing interesting here'
            ].join('\n'),
            '^$$', true, false, null,
            [
                [2, 1, 2, 1],
                [4, 1, 4, 1]
            ]
        );
    }

    // test('multiline find 1')
    function testMultilineFind1() {
        assertFindMatches(
            [
                'Just some text text',
                'Just some text text',
                'some text again',
                'again some text'
            ].join('\n'),
            'text\\n', true, false, null,
            [
                [1, 16, 2, 1],
                [2, 16, 3, 1],
            ]
        );
    }

    // test('multiline find 2')
    function testMultilineFind2() {
        assertFindMatches(
            [
                'Just some text text',
                'Just some text text',
                'some text again',
                'again some text'
            ].join('\n'),
            'text\\nJust', true, false, null,
            [
                [1, 16, 2, 5]
            ]
        );
    }

    // test('multiline find 3')
    function testMultilineFind3() {
        assertFindMatches(
            [
                'Just some text text',
                'Just some text text',
                'some text again',
                'again some text'
            ].join('\n'),
            '\\nagain', true, false, null,
            [
                [3, 16, 4, 6]
            ]
        );
    }

    // test('multiline find 4')
    function testMultilineFind4() {
        assertFindMatches(
            [
                'Just some text text',
                'Just some text text',
                'some text again',
                'again some text'
            ].join('\n'),
            '.*\\nJust.*\\n', true, false, null,
            [
                [1, 1, 3, 1]
            ]
        );
    }

    // test('multiline find with line beginning regex')
    function testMultilineFindWithLineBeginningRegex() {
        assertFindMatches(
            [
                'if',
                'else',
                '',
                'if',
                'else'
            ].join('\n'),
            '^if\\nelse', true, false, null,
            [
                [1, 1, 2, 5],
                [4, 1, 5, 5]
            ]
        );
    }

    // test('matching empty lines using boundary expression')
    function testMatchingEmptyLinesUsingBoundaryExpression() {
        assertFindMatches(
            [
                'if',
                '',
                'else',
                '  ',
                'if',
                ' ',
                'else'
            ].join('\n'),
            '^\\s*$$\\n', true, false, null,
            [
                [2, 1, 3, 1],
                [4, 1, 5, 1],
                [6, 1, 7, 1]
            ]
        );
    }

    // test('matching lines starting with A and ending with B')
    function testMatchingLinesStartingWithAAndEndingWithB() {
        assertFindMatches(
            [
                'a if b',
                'a',
                'ab',
                'eb'
            ].join('\n'),
            '^a.*b$$', true, false, null,
            [
                [1, 1, 1, 7],
                [3, 1, 3, 3]
            ]
        );
    }

    // test('multiline find with line ending regex')
    function testMultilineFindWithLineEndingRegex() {
        assertFindMatches(
            [
                'if',
                'else',
                '',
                'if',
                'elseif',
                'else'
            ].join('\n'),
            'if\\nelse$$', true, false, null,
            [
                [1, 1, 2, 5],
                [5, 5, 6, 5]
            ]
        );
    }

    // test('issue #4836 - ^.*$')
    function testIssue4836() {
        assertFindMatches(
            [
                'Just some text text',
                '',
                'some text again',
                '',
                'again some text'
            ].join('\n'),
            '^.*$$', true, false, null,
            [
                [1, 1, 1, 20],
                [2, 1, 2, 1],
                [3, 1, 3, 16],
                [4, 1, 4, 1],
                [5, 1, 5, 16],
            ]
        );
    }

    // test('multiline find for non-regex string')
    function testMultilineFindForNonRegexString() {
        assertFindMatches(
            [
                'Just some text text',
                'some text text',
                'some text again',
                'again some text',
                'but not some'
            ].join('\n'),
            'text\nsome', false, false, null,
            [
                [1, 16, 2, 5],
                [2, 11, 3, 5],
            ]
        );
    }

    // test('issue #3623: Match whole word does not work for not latin characters')
    function testIssue3623MatchWholeWordDoesNotWorkForNotLatinCharacters() {
        assertFindMatches(
            [
                'я',
                'компилятор',
                'обфускация',
                ':я-я'
            ].join('\n'),
            'я', false, false, WordHelper.USUAL_WORD_SEPARATORS,
            [
                [1, 1, 1, 2],
                [4, 2, 4, 3],
                [4, 4, 4, 5],
            ]
        );
    }

    // test('issue #27459: Match whole words regression')
    function testIssue27459MatchWholeWordsRegression() {
        assertFindMatches(
            [
                'this._register(this._textAreaInput.onKeyDown((e: IKeyboardEvent) => {',
                '	this._viewController.emitKeyDown(e);',
                '}));',
            ].join('\n'),
            '((e: ', false, false, WordHelper.USUAL_WORD_SEPARATORS,
            [
                [1, 45, 1, 50]
            ]
        );
    }

    // test('issue #27594: Search results disappear')
    function testIssue27594SearchResultsDisappear() {
        assertFindMatches(
            [
                'this.server.listen(0);',
            ].join('\n'),
            'listen(', false, false, WordHelper.USUAL_WORD_SEPARATORS,
            [
                [1, 13, 1, 20]
            ]
        );
    }

    // test('findNextMatch without regex')
    function testFindNextMatchWithoutRegex() {
        final model = createTextModel('line line one\nline two\nthree');

        final searchParams = new SearchParams('line', false, false, null);

        var actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 1), false);
        assertFindMatch(actual, new Range(1, 1, 1, 5));

        actual = TextModelSearch.findNextMatch(model, searchParams, actual.range.getEndPosition(), false);
        assertFindMatch(actual, new Range(1, 6, 1, 10));

        actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 3), false);
        assertFindMatch(actual, new Range(1, 6, 1, 10));

        actual = TextModelSearch.findNextMatch(model, searchParams, actual.range.getEndPosition(), false);
        assertFindMatch(actual, new Range(2, 1, 2, 5));

        actual = TextModelSearch.findNextMatch(model, searchParams, actual.range.getEndPosition(), false);
        assertFindMatch(actual, new Range(1, 1, 1, 5));

        model.dispose();
    }

    // test('findNextMatch with beginning boundary regex')
    function testFindNextMatchWithBeginningBoundaryRegex() {
        final model = createTextModel('line one\nline two\nthree');

        final searchParams = new SearchParams('^line', true, false, null);

        var actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 1), false);
        assertFindMatch(actual, new Range(1, 1, 1, 5));

        actual = TextModelSearch.findNextMatch(model, searchParams, actual.range.getEndPosition(), false);
        assertFindMatch(actual, new Range(2, 1, 2, 5));

        actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 3), false);
        assertFindMatch(actual, new Range(2, 1, 2, 5));

        actual = TextModelSearch.findNextMatch(model, searchParams, actual.range.getEndPosition(), false);
        assertFindMatch(actual, new Range(1, 1, 1, 5));

        model.dispose();
    }

    // test('findNextMatch with beginning boundary regex and line has repetitive beginnings')
    function testFindNextMatchWithBeginningBoundaryRegexAndLineHasRepetitiveBeginnings() {
        final model = createTextModel('line line one\nline two\nthree');

        final searchParams = new SearchParams('^line', true, false, null);

        var actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 1), false);
        assertFindMatch(actual, new Range(1, 1, 1, 5));

        actual = TextModelSearch.findNextMatch(model, searchParams, actual.range.getEndPosition(), false);
        assertFindMatch(actual, new Range(2, 1, 2, 5));

        actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 3), false);
        assertFindMatch(actual, new Range(2, 1, 2, 5));

        actual = TextModelSearch.findNextMatch(model, searchParams, actual.range.getEndPosition(), false);
        assertFindMatch(actual, new Range(1, 1, 1, 5));

        model.dispose();
    }

    // test('findNextMatch with beginning boundary multiline regex and line has repetitive beginnings')
    function testFindNextMatchWithBeginningBoundaryMultilineRegexAndLineHasRepetitiveBeginnings() {
        final model = createTextModel('line line one\nline two\nline three\nline four');

        final searchParams = new SearchParams('^line.*\\nline', true, false, null);

        var actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 1), false);
        assertFindMatch(actual, new Range(1, 1, 2, 5));

        actual = TextModelSearch.findNextMatch(model, searchParams, actual.range.getEndPosition(), false);
        assertFindMatch(actual, new Range(3, 1, 4, 5));

        actual = TextModelSearch.findNextMatch(model, searchParams, new Position(2, 1), false);
        assertFindMatch(actual, new Range(2, 1, 3, 5));

        model.dispose();
    }

    // test('findNextMatch with ending boundary regex')
    function testFindNextMatchWithEndingBoundaryRegex() {
        final model = createTextModel('one line line\ntwo line\nthree');

        final searchParams = new SearchParams('line$$', true, false, null);

        var actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 1), false);
        assertFindMatch(actual, new Range(1, 10, 1, 14));

        actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 4), false);
        assertFindMatch(actual, new Range(1, 10, 1, 14));

        actual = TextModelSearch.findNextMatch(model, searchParams, actual.range.getEndPosition(), false);
        assertFindMatch(actual, new Range(2, 5, 2, 9));

        actual = TextModelSearch.findNextMatch(model, searchParams, actual.range.getEndPosition(), false);
        assertFindMatch(actual, new Range(1, 10, 1, 14));

        model.dispose();
    }

    // test('findMatches with capturing matches')
    function testFindMatchesWithCapturingMatches() {
        final model = createTextModel('one line line\ntwo line\nthree');

        final searchParams = new SearchParams('(l(in)e)', true, false, null);

        final actual = TextModelSearch.findMatches(model, searchParams, model.getFullModelRange(), true, 100);
        assertDeepEquals(actual, [
            new FindMatch(new Range(1, 5, 1, 9), ['line', 'line', 'in']),
            new FindMatch(new Range(1, 10, 1, 14), ['line', 'line', 'in']),
            new FindMatch(new Range(2, 5, 2, 9), ['line', 'line', 'in']),
        ]);

        model.dispose();
    }

    // test('findMatches multiline with capturing matches')
    function testFindMatchesMultilineWithCapturingMatches() {
        final model = createTextModel('one line line\ntwo line\nthree');

        final searchParams = new SearchParams('(l(in)e)\\n', true, false, null);

        final actual = TextModelSearch.findMatches(model, searchParams, model.getFullModelRange(), true, 100);
        assertDeepEquals(actual, [
            new FindMatch(new Range(1, 10, 2, 1), ['line\n', 'line', 'in']),
            new FindMatch(new Range(2, 5, 3, 1), ['line\n', 'line', 'in']),
        ]);

        model.dispose();
    }

    // test('findNextMatch with capturing matches')
    function testFindNextMatchWithCapturingMatches() {
        final model = createTextModel('one line line\ntwo line\nthree');

        final searchParams = new SearchParams('(l(in)e)', true, false, null);

        final actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 1), true);
        assertFindMatch(actual, new Range(1, 5, 1, 9), ['line', 'line', 'in']);

        model.dispose();
    }

    // test('findNextMatch multiline with capturing matches')
    function testFindNextMatchMultilineWithCapturingMatches() {
        final model = createTextModel('one line line\ntwo line\nthree');

        final searchParams = new SearchParams('(l(in)e)\\n', true, false, null);

        final actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 1), true);
        assertFindMatch(actual, new Range(1, 10, 2, 1), ['line\n', 'line', 'in']);

        model.dispose();
    }

    // test('findPreviousMatch with capturing matches')
    function testFindPreviousMatchWithCapturingMatches() {
        final model = createTextModel('one line line\ntwo line\nthree');

        final searchParams = new SearchParams('(l(in)e)', true, false, null);

        final actual = TextModelSearch.findPreviousMatch(model, searchParams, new Position(1, 1), true);
        assertFindMatch(actual, new Range(2, 5, 2, 9), ['line', 'line', 'in']);

        model.dispose();
    }

    // test('findPreviousMatch multiline with capturing matches')
    function testFindPreviousMatchMultilineWithCapturingMatches() {
        final model = createTextModel('one line line\ntwo line\nthree');

        final searchParams = new SearchParams('(l(in)e)\\n', true, false, null);

        final actual = TextModelSearch.findPreviousMatch(model, searchParams, new Position(1, 1), true);
        assertFindMatch(actual, new Range(2, 5, 3, 1), ['line\n', 'line', 'in']);

        model.dispose();
    }

    // test('\\n matches \\r\\n')
    function testNMatchesRN() {
        final model = createTextModel('a\r\nb\r\nc\r\nd\r\ne\r\nf\r\ng\r\nh\r\ni');

        assertEquals(model.getEOL(), '\r\n');

        var searchParams = new SearchParams('h\\n', true, false, null);
        var actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 1), true);
        actual = TextModelSearch.findMatches(model, searchParams, model.getFullModelRange(), true, 1000)[0];
        assertFindMatch(actual, new Range(8, 1, 9, 1), ['h\n']);

        searchParams = new SearchParams('g\\nh\\n', true, false, null);
        actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 1), true);
        actual = TextModelSearch.findMatches(model, searchParams, model.getFullModelRange(), true, 1000)[0];
        assertFindMatch(actual, new Range(7, 1, 9, 1), ['g\nh\n']);

        searchParams = new SearchParams('\\ni', true, false, null);
        actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 1), true);
        actual = TextModelSearch.findMatches(model, searchParams, model.getFullModelRange(), true, 1000)[0];
        assertFindMatch(actual, new Range(8, 2, 9, 2), ['\ni']);

        model.dispose();
    }

    // test('\\r can never be found')
    function testRCanNeverBeFound() {
        final model = createTextModel('a\r\nb\r\nc\r\nd\r\ne\r\nf\r\ng\r\nh\r\ni');

        assertEquals(model.getEOL(), '\r\n');

        final searchParams = new SearchParams('\\r\\n', true, false, null);
        final actual = TextModelSearch.findNextMatch(model, searchParams, new Position(1, 1), true);
        assertEquals(actual, null);
        assertDeepEquals(TextModelSearch.findMatches(model, searchParams, model.getFullModelRange(), true, 1000), []);

        model.dispose();
    }

    // test('parseSearchRequest invalid')
    function testParseSearchRequestInvalid() {
        assertParseSearchResult('', true, true, WordHelper.USUAL_WORD_SEPARATORS, null);
        assertParseSearchResult('(', true, false, null, null);
    }

    // test('parseSearchRequest non regex')
    function testParseSearchRequestNonRegex() {
        final usualWordSeparators = WordCharacterClassifier.getMapForWordSeparators(WordHelper.USUAL_WORD_SEPARATORS, []);
        assertParseSearchResult('foo', false, false, null, new SearchData(new RegExp('foo', 'giu'), null, null));
        assertParseSearchResult('foo', false, false, WordHelper.USUAL_WORD_SEPARATORS, new SearchData(new RegExp('foo', 'giu'), usualWordSeparators, null));
        assertParseSearchResult('foo', false, true, null, new SearchData(new RegExp('foo', 'gu'), null, 'foo'));
        assertParseSearchResult('foo', false, true, WordHelper.USUAL_WORD_SEPARATORS, new SearchData(new RegExp('foo', 'gu'), usualWordSeparators, 'foo'));
        assertParseSearchResult('foo\\n', false, false, null, new SearchData(new RegExp('foo\\\\n', 'giu'), null, null));
        assertParseSearchResult('foo\\\\n', false, false, null, new SearchData(new RegExp('foo\\\\\\\\n', 'giu'), null, null));
        assertParseSearchResult('foo\\r', false, false, null, new SearchData(new RegExp('foo\\\\r', 'giu'), null, null));
        assertParseSearchResult('foo\\\\r', false, false, null, new SearchData(new RegExp('foo\\\\\\\\r', 'giu'), null, null));
    }

    // test('parseSearchRequest regex')
    function testParseSearchRequestRegex() {
        final usualWordSeparators = WordCharacterClassifier.getMapForWordSeparators(WordHelper.USUAL_WORD_SEPARATORS, []);
        assertParseSearchResult('foo', true, false, null, new SearchData(new RegExp('foo', 'giu'), null, null));
        assertParseSearchResult('foo', true, false, WordHelper.USUAL_WORD_SEPARATORS, new SearchData(new RegExp('foo', 'giu'), usualWordSeparators, null));
        assertParseSearchResult('foo', true, true, null, new SearchData(new RegExp('foo', 'gu'), null, null));
        assertParseSearchResult('foo', true, true, WordHelper.USUAL_WORD_SEPARATORS, new SearchData(new RegExp('foo', 'gu'), usualWordSeparators, null));
        assertParseSearchResult('foo\\n', true, false, null, new SearchData(new RegExp('foo\\n', 'gimu'), null, null));
        assertParseSearchResult('foo\\\\n', true, false, null, new SearchData(new RegExp('foo\\\\n', 'giu'), null, null));
        assertParseSearchResult('foo\\r', true, false, null, new SearchData(new RegExp('foo\\r', 'gimu'), null, null));
        assertParseSearchResult('foo\\\\r', true, false, null, new SearchData(new RegExp('foo\\\\r', 'giu'), null, null));
    }

    // test('issue #53415. \W should match line break.')
    function testIssue53415WShouldMatchLineBreak() {
        assertFindMatches(
            [
                'text',
                '180702-',
                '180703-180704'
            ].join('\n'),
            '\\d{6}-\\W', true, false, null,
            [
                [2, 1, 3, 1]
            ]
        );

        assertFindMatches(
            [
                'Just some text',
                '',
                'Just'
            ].join('\n'),
            '\\W', true, false, null,
            [
                [1, 5, 1, 6],
                [1, 10, 1, 11],
                [1, 15, 2, 1],
                [2, 1, 3, 1]
            ]
        );

        // Line break doesn't affect the result as we always use \n as line break when doing search
        assertFindMatches(
            [
                'Just some text',
                '',
                'Just'
            ].join('\r\n'),
            '\\W', true, false, null,
            [
                [1, 5, 1, 6],
                [1, 10, 1, 11],
                [1, 15, 2, 1],
                [2, 1, 3, 1]
            ]
        );

        assertFindMatches(
            [
                'Just some text',
                '\tJust',
                'Just'
            ].join('\n'),
            '\\W', true, false, null,
            [
                [1, 5, 1, 6],
                [1, 10, 1, 11],
                [1, 15, 2, 1],
                [2, 1, 2, 2],
                [2, 6, 3, 1],
            ]
        );

        // line break is seen as one non-word character
        assertFindMatches(
            [
                'Just  some text',
                '',
                'Just'
            ].join('\n'),
            '\\W{2}', true, false, null,
            [
                [1, 5, 1, 7],
                [1, 16, 3, 1]
            ]
        );

        // even if it's \r\n
        assertFindMatches(
            [
                'Just  some text',
                '',
                'Just'
            ].join('\r\n'),
            '\\W{2}', true, false, null,
            [
                [1, 5, 1, 7],
                [1, 16, 3, 1]
            ]
        );
    }

    // test('Simple find using unicode escape sequences')
    function testSimpleFindUsingUnicodeEscapeSequences() {
        assertFindMatches(
            regularText.join('\n'),
            '\\u{0066}\\u006f\\u006F', true, false, null,
            [
                [1, 14, 1, 17],
                [1, 44, 1, 47],
                [2, 22, 2, 25],
                [2, 48, 2, 51],
                [4, 59, 4, 62]
            ]
        );
    }

    // test('isMultilineRegexSource')
    function testIsMultilineRegexSource() {
        assertTrue(!TextModelSearch.isMultilineRegexSource('foo'));
        assertTrue(!TextModelSearch.isMultilineRegexSource(''));
        assertTrue(!TextModelSearch.isMultilineRegexSource('foo\\sbar'));
        assertTrue(!TextModelSearch.isMultilineRegexSource('\\\\notnewline'));

        assertTrue(TextModelSearch.isMultilineRegexSource('foo\\nbar'));
        assertTrue(TextModelSearch.isMultilineRegexSource('foo\\nbar\\s'));
        assertTrue(TextModelSearch.isMultilineRegexSource('foo\\r\\n'));
        assertTrue(TextModelSearch.isMultilineRegexSource('\\n'));
        assertTrue(TextModelSearch.isMultilineRegexSource('foo\\W'));
        assertTrue(TextModelSearch.isMultilineRegexSource('foo\n'));
        assertTrue(TextModelSearch.isMultilineRegexSource('foo\r\n'));
    }

    // test('issue #74715. \\d* finds empty string and stops searching.')
    function testIssue74715DFindsEmptyStringAndStopsSearching() {
        final model = createTextModel('10.243.30.10');

        final searchParams = new SearchParams('\\d*', true, false, null);

        final actual = TextModelSearch.findMatches(model, searchParams, model.getFullModelRange(), true, 100);
        assertDeepEquals(actual, [
            new FindMatch(new Range(1, 1, 1, 3), ['10']),
            new FindMatch(new Range(1, 3, 1, 3), ['']),
            new FindMatch(new Range(1, 4, 1, 7), ['243']),
            new FindMatch(new Range(1, 7, 1, 7), ['']),
            new FindMatch(new Range(1, 8, 1, 10), ['30']),
            new FindMatch(new Range(1, 10, 1, 10), ['']),
            new FindMatch(new Range(1, 11, 1, 13), ['10'])
        ]);

        model.dispose();
    }

    // test('issue #100134. Zero-length matches should properly step over surrogate pairs')
    function testIssue100134ZeroLengthMatchesShouldProperlyStepOverSurrogatePairs() {
        // 1[Laptop]1 - there shoud be no matches inside of [Laptop] emoji
        assertFindMatches('1\u{1F4BB}1', '()', true, false, null,
            [
                [1, 1, 1, 1],
                [1, 2, 1, 2],
                [1, 4, 1, 4],
                [1, 5, 1, 5],

            ]
        );
        // 1[Hacker Cat]1 = 1[Cat Face][ZWJ][Laptop]1 - there shoud be matches between emoji and ZWJ
        // there shoud be no matches inside of [Cat Face] and [Laptop] emoji
        assertFindMatches('1\u{1F431}\u{200D}\u{1F4BB}1', '()', true, false, null,
            [
                [1, 1, 1, 1],
                [1, 2, 1, 2],
                [1, 4, 1, 4],
                [1, 5, 1, 5],
                [1, 7, 1, 7],
                [1, 8, 1, 8]
            ]
        );
    }
}
