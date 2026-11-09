// Ported from vscode src/vs/editor/contrib/smartSelect/test/browser/smartSelect.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.smartSelect;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.RegExp;
import cityscape.base.common.Uri;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.SelectionRange;
import cityscape.common.Languages.SelectionRangeProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.Language.ILanguageSelection;
import cityscape.common.services.ModelService;
import cityscape.contrib.smartSelect.view.BracketSelections;
import cityscape.contrib.smartSelect.view.SmartSelect;
import cityscape.contrib.smartSelect.view.WordSelections;
import testing.TestCase;
import tests.modes.supports.OnEnterRules;

class StaticLanguageSelector implements ILanguageSelection {

    public final onDidChange:Event<String> = (_) -> Lifecycle.toDisposable(() -> {});

    final _languageId:String;

    public var languageId(get, never):String;
    function get_languageId():String {
        return _languageId;
    }

    public function new(languageId:String) {
        _languageId = languageId;
    }

}

/**
 * A provider given as an object literal in vscode.
 */
private class TestSelectionRangeProvider implements SelectionRangeProvider {

    final ranges:Array<Array<SelectionRange>>;

    public function new(ranges:Array<Array<SelectionRange>>) {
        this.ranges = ranges;
    }

    public function provideSelectionRanges(model:ITextModel, positions:Array<Position>, token:CancellationToken, resolve:(ranges:Null<Array<Array<SelectionRange>>>) -> Void):Void {
        resolve(ranges);
    }

}

/**
 * suite('SmartSelect')
 *
 * The providers resolve at once here (vscode awaits their promises), and
 * `provideSelectionRanges` calls back before returning.
 */
class SmartSelectTest extends TestCase {

    static final OriginalBracketSelectionRangeProviderMaxDuration = BracketSelectionRangeProvider._maxDuration;

    final languageId = 'mockJSMode';
    var disposables:DisposableStore;
    var modelService:ModelService;
    var providers:LanguageFeatureRegistry<SelectionRangeProvider>;

    override function setup():Void {
        // suiteSetup
        BracketSelectionRangeProvider._maxDuration = 5000; // 5 seconds

        disposables = new DisposableStore();
        providers = new LanguageFeatureRegistry<SelectionRangeProvider>();
        final instantiationService = new Cityscape();
        modelService = instantiationService.modelService;
        final languagConfigurationService = instantiationService.languageConfigurationService;
        final languageService = instantiationService.languageService;
        disposables.add(languageService.registerLanguage({id: languageId}));
        disposables.add(languagConfigurationService.register(languageId, {
            brackets: [
                ['(', ')'],
                ['{', '}'],
                ['[', ']']
            ],
            onEnterRules: OnEnterRules.javascriptOnEnterRules,
            wordPattern: new RegExp("(-?\\d*\\.\\d\\w*)|([^\\`\\~\\!\\@\\#\\$\\%\\^\\&\\*\\(\\)\\=\\+\\[\\{\\]\\}\\\\\\;\\:\\'\\\"\\,\\.\\<\\>\\/\\?\\s]+)", 'g')
        }));
    }

    override function teardown():Void {
        disposables.dispose();
        // suiteTeardown
        BracketSelectionRangeProvider._maxDuration = OriginalBracketSelectionRangeProviderMaxDuration;
    }

    function assertGetRangesToPosition(text:Array<String>, lineNumber:Int, column:Int, ranges:Array<Range>, selectLeadingAndTrailingWhitespace = true, ?pos:haxe.PosInfos):Void {
        final uri = Uri.file('test.js');
        final model = modelService.createModel(text.join('\n'), new StaticLanguageSelector(languageId), uri);
        var result:Null<Array<Array<Range>>> = null;
        SmartSelect.provideSelectionRanges(providers, model, [new Position(lineNumber, column)], {selectLeadingAndTrailingWhitespace: selectLeadingAndTrailingWhitespace, selectSubwords: true}, CancellationTokens.None, (r) -> result = r);
        final actual = result[0];
        final actualStr = [for (r in actual) new Range(r.startLineNumber, r.startColumn, r.endLineNumber, r.endColumn).toString()];
        ranges.reverse();
        final desiredStr = [for (r in ranges) r.toString()];

        assertDeepEquals(desiredStr, actualStr, '\nA: ${actualStr} VS \nE: ${desiredStr}', pos);
        modelService.destroyModel(uri);
    }

    function testGetRangesToPosition1() {

        assertGetRangesToPosition([
            'function a(bar, foo){',
            '\tif (bar) {',
            '\t\treturn (bar + (2 * foo))',
            '\t}',
            '}'
        ], 3, 20, [
            new Range(1, 1, 5, 2), // all
            new Range(1, 21, 5, 2), // {} outside
            new Range(1, 22, 5, 1), // {} inside
            new Range(2, 1, 4, 3), // block
            new Range(2, 1, 4, 3),
            new Range(2, 2, 4, 3),
            new Range(2, 11, 4, 3),
            new Range(2, 12, 4, 2),
            new Range(3, 1, 3, 27), // line w/ triva
            new Range(3, 3, 3, 27), // line w/o triva
            new Range(3, 10, 3, 27), // () outside
            new Range(3, 11, 3, 26), // () inside
            new Range(3, 17, 3, 26), // () outside
            new Range(3, 18, 3, 25), // () inside
        ]);
    }

    function testConfigSelectLeadingAndTrailingWhitespace() {

        assertGetRangesToPosition([
            'aaa',
            '\tbbb',
            ''
        ], 2, 3, [
            new Range(1, 1, 3, 1), // all
            new Range(2, 1, 2, 5), // line w/ triva
            new Range(2, 2, 2, 5), // bbb
        ], true);

        assertGetRangesToPosition([
            'aaa',
            '\tbbb',
            ''
        ], 2, 3, [
            new Range(1, 1, 3, 1), // all
            new Range(2, 2, 2, 5), // () inside
        ], false);
    }

    function testGetRangesToPosition56886SkipEmptyLinesCorrectly() {

        assertGetRangesToPosition([
            'function a(bar, foo){',
            '\tif (bar) {',
            '',
            '\t}',
            '}'
        ], 3, 1, [
            new Range(1, 1, 5, 2),
            new Range(1, 21, 5, 2),
            new Range(1, 22, 5, 1),
            new Range(2, 1, 4, 3),
            new Range(2, 1, 4, 3),
            new Range(2, 2, 4, 3),
            new Range(2, 11, 4, 3),
            new Range(2, 12, 4, 2),
        ]);
    }

    function testGetRangesToPosition56886DoNotSkipLinesWithOnlyWhitespaces() {

        assertGetRangesToPosition([
            'function a(bar, foo){',
            '\tif (bar) {',
            ' ',
            '\t}',
            '}'
        ], 3, 1, [
            new Range(1, 1, 5, 2), // all
            new Range(1, 21, 5, 2), // {} outside
            new Range(1, 22, 5, 1), // {} inside
            new Range(2, 1, 4, 3),
            new Range(2, 1, 4, 3),
            new Range(2, 2, 4, 3),
            new Range(2, 11, 4, 3),
            new Range(2, 12, 4, 2),
            new Range(3, 1, 3, 2), // block
            new Range(3, 1, 3, 2) // empty line
        ]);
    }

    function testGetRangesToPosition40658CursorAtFirstPositionInsideBracketsShouldSelectLineInside() {

        assertGetRangesToPosition([
            ' [ ]',
            ' { } ',
            '( ) '
        ], 2, 3, [
            new Range(1, 1, 3, 5),
            new Range(2, 1, 2, 6), // line w/ triava
            new Range(2, 2, 2, 5), // {} inside, line w/o triva
            new Range(2, 3, 2, 4) // {} inside
        ]);
    }

    function testGetRangesToPosition40658CursorInEmptyBracketsShouldRevealBracketsFirst() {

        assertGetRangesToPosition([
            ' [] ',
            ' { } ',
            '  ( ) '
        ], 1, 3, [
            new Range(1, 1, 3, 7), // all
            new Range(1, 1, 1, 5), // line w/ trival
            new Range(1, 2, 1, 4), // [] outside, line w/o trival
            new Range(1, 3, 1, 3), // [] inside
        ]);
    }

    function testGetRangesToPosition40658TokensBeforeBracketWillBeRevealedFirst() {

        assertGetRangesToPosition([
            '  [] ',
            ' { } ',
            'selectthis( ) '
        ], 3, 11, [
            new Range(1, 1, 3, 15), // all
            new Range(3, 1, 3, 15), // line w/ trivia
            new Range(3, 1, 3, 14), // line w/o trivia
            new Range(3, 1, 3, 11) // word
        ]);
    }

    // -- bracket selections

    function assertRanges(provider:SelectionRangeProvider, value:String, expected:Array<IRange>, ?pos:haxe.PosInfos):Void {
        final index = value.indexOf('|');
        value = StringTools.replace(value, '|', ''); // only one | in the values of the tests

        final model = modelService.createModel(value, new StaticLanguageSelector(languageId), Uri.parse('fake:lang'));
        final position = model.getPositionAt(index);
        var all:Null<Array<Array<SelectionRange>>> = null;
        provider.provideSelectionRanges(model, [position], CancellationTokens.None, (r) -> all = r);
        final ranges = all[0];

        modelService.destroyModel(model.uri);

        expected = expected.copy();
        assertEquals(expected.length, ranges.length, null, pos);
        for (range in ranges) {
            final exp = expected.length > 0 ? expected.shift() : null;
            assertTrue(Range.equalsRangeStatic(range.range, exp), 'A=${Range.lift(range.range)} <> E=${Range.lift(exp)}', pos);
        }
    }

    function testBracketSelection() {
        assertRanges(new BracketSelectionRangeProvider(), '(|)', [
            new Range(1, 2, 1, 2), new Range(1, 1, 1, 3)
        ]);

        assertRanges(new BracketSelectionRangeProvider(), '[[[](|)]]', [
            new Range(1, 6, 1, 6), new Range(1, 5, 1, 7), // ()
            new Range(1, 3, 1, 7), new Range(1, 2, 1, 8), // [[]()]
            new Range(1, 2, 1, 8), new Range(1, 1, 1, 9), // [[[]()]]
        ]);

        assertRanges(new BracketSelectionRangeProvider(), '[a[](|)a]', [
            new Range(1, 6, 1, 6), new Range(1, 5, 1, 7),
            new Range(1, 2, 1, 8), new Range(1, 1, 1, 9),
        ]);

        // no bracket
        assertRanges(new BracketSelectionRangeProvider(), 'fofof|fofo', []);

        // empty
        assertRanges(new BracketSelectionRangeProvider(), '[[[]()]]|', []);
        assertRanges(new BracketSelectionRangeProvider(), '|[[[]()]]', []);

        // edge
        assertRanges(new BracketSelectionRangeProvider(), '[|[[]()]]', [new Range(1, 2, 1, 8), new Range(1, 1, 1, 9)]);
        assertRanges(new BracketSelectionRangeProvider(), '[[[]()]|]', [new Range(1, 2, 1, 8), new Range(1, 1, 1, 9)]);

        assertRanges(new BracketSelectionRangeProvider(), 'aaa(aaa)bbb(b|b)ccc(ccc)', [new Range(1, 13, 1, 15), new Range(1, 12, 1, 16)]);
        assertRanges(new BracketSelectionRangeProvider(), '(aaa(aaa)bbb(b|b)ccc(ccc))', [new Range(1, 14, 1, 16), new Range(1, 13, 1, 17), new Range(1, 2, 1, 25), new Range(1, 1, 1, 26)]);
    }

    function testBracketWithLeadingTrailing() {

        assertRanges(new BracketSelectionRangeProvider(), 'for(a of b){\n  foo(|);\n}', [
            new Range(2, 7, 2, 7), new Range(2, 6, 2, 8),
            new Range(1, 13, 3, 1), new Range(1, 12, 3, 2),
            new Range(1, 1, 3, 2), new Range(1, 1, 3, 2),
        ]);

        assertRanges(new BracketSelectionRangeProvider(), 'for(a of b)\n{\n  foo(|);\n}', [
            new Range(3, 7, 3, 7), new Range(3, 6, 3, 8),
            new Range(2, 2, 4, 1), new Range(2, 1, 4, 2),
            new Range(1, 1, 4, 2), new Range(1, 1, 4, 2),
        ]);
    }

    function testInWordRanges() {

        assertRanges(new WordSelectionRangeProvider(), 'f|ooBar', [
            new Range(1, 1, 1, 4), // foo
            new Range(1, 1, 1, 7), // fooBar
            new Range(1, 1, 1, 7), // doc
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'f|oo_Ba', [
            new Range(1, 1, 1, 4),
            new Range(1, 1, 1, 7),
            new Range(1, 1, 1, 7),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'f|oo-Ba', [
            new Range(1, 1, 1, 4),
            new Range(1, 1, 1, 7),
            new Range(1, 1, 1, 7),
        ]);
    }

    function testInWordRangesWithSelectSubwordsFalse() {

        assertRanges(new WordSelectionRangeProvider(false), 'f|ooBar', [
            new Range(1, 1, 1, 7),
            new Range(1, 1, 1, 7),
        ]);

        assertRanges(new WordSelectionRangeProvider(false), 'f|oo_Ba', [
            new Range(1, 1, 1, 7),
            new Range(1, 1, 1, 7),
        ]);

        assertRanges(new WordSelectionRangeProvider(false), 'f|oo-Ba', [
            new Range(1, 1, 1, 7),
            new Range(1, 1, 1, 7),
        ]);
    }

    function testDefaultSelectionShouldSelectCurrentWordHumpFirstInCamelCase67493() {

        assertRanges(new WordSelectionRangeProvider(), 'Abs|tractSmartSelect', [
            new Range(1, 1, 1, 9),
            new Range(1, 1, 1, 20),
            new Range(1, 1, 1, 20),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'AbstractSma|rtSelect', [
            new Range(1, 9, 1, 14),
            new Range(1, 1, 1, 20),
            new Range(1, 1, 1, 20),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'Abstrac-Sma|rt-elect', [
            new Range(1, 9, 1, 14),
            new Range(1, 1, 1, 20),
            new Range(1, 1, 1, 20),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'Abstrac_Sma|rt_elect', [
            new Range(1, 9, 1, 14),
            new Range(1, 1, 1, 20),
            new Range(1, 1, 1, 20),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'Abstrac_Sma|rt-elect', [
            new Range(1, 9, 1, 14),
            new Range(1, 1, 1, 20),
            new Range(1, 1, 1, 20),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'Abstrac_Sma|rtSelect', [
            new Range(1, 9, 1, 14),
            new Range(1, 1, 1, 20),
            new Range(1, 1, 1, 20),
        ]);
    }

    function testSmartSelectOnlyAddLineRangesIfTheyReContainedByTheNextRange73850() {

        final reg = providers.register('*', new TestSelectionRangeProvider([[
            {range: {startLineNumber: 1, startColumn: 10, endLineNumber: 1, endColumn: 11}},
            {range: {startLineNumber: 1, startColumn: 10, endLineNumber: 3, endColumn: 2}},
            {range: {startLineNumber: 1, startColumn: 1, endLineNumber: 3, endColumn: 2}},
        ]]));

        assertGetRangesToPosition(['type T = {', '\tx: number', '}'], 1, 10, [
            new Range(1, 1, 3, 2), // all
            new Range(1, 10, 3, 2), // { ... }
            new Range(1, 10, 1, 11), // {
        ]);

        reg.dispose();
    }

    function testExpandSelectionInWordsWithUnderscoresIsInconsistent90589() {

        assertRanges(new WordSelectionRangeProvider(), 'Hel|lo_World', [
            new Range(1, 1, 1, 6),
            new Range(1, 1, 1, 12),
            new Range(1, 1, 1, 12),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'Hello_Wo|rld', [
            new Range(1, 7, 1, 12),
            new Range(1, 1, 1, 12),
            new Range(1, 1, 1, 12),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'Hello|_World', [
            new Range(1, 1, 1, 6),
            new Range(1, 1, 1, 12),
            new Range(1, 1, 1, 12),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'Hello_|World', [
            new Range(1, 7, 1, 12),
            new Range(1, 1, 1, 12),
            new Range(1, 1, 1, 12),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'Hello|-World', [
            new Range(1, 1, 1, 6),
            new Range(1, 1, 1, 12),
            new Range(1, 1, 1, 12),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'Hello-|World', [
            new Range(1, 7, 1, 12),
            new Range(1, 1, 1, 12),
            new Range(1, 1, 1, 12),
        ]);

        assertRanges(new WordSelectionRangeProvider(), 'Hello|World', [
            new Range(1, 6, 1, 11),
            new Range(1, 1, 1, 11),
            new Range(1, 1, 1, 11),
        ]);
    }

}
