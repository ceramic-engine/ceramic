// Ported from vscode src/vs/editor/contrib/suggest/test/browser/completionModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.suggest;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.contrib.suggest.view.CompletionModel;
import cityscape.contrib.suggest.view.Suggest;
import cityscape.contrib.suggest.view.WordDistance;
import haxe.extern.EitherType;
import testing.TestCase;

/**
 * A provider that provides nothing (the object literal of
 * `createSuggestItem`).
 */
class NullCompletionProvider implements CompletionItemProvider {
    public var _debugDisplayName(default, null):Null<String> = 'test';
    public var triggerCharacters(default, null):Null<Array<String>> = null;
    public var resolveCompletionItem(default, null):Null<(item:cityscape.common.Languages.CompletionItem, token:CancellationToken, resolve:(item:Null<cityscape.common.Languages.CompletionItem>) -> Void) -> Void> = null;

    public function new() {}

    public function provideCompletionItems(model:cityscape.common.Model.ITextModel, position:Position, context:CompletionContext, token:CancellationToken, resolve:(list:Null<CompletionList>) -> Void):Void {
        resolve(null);
    }
}

/**
 * suite('CompletionModel').
 *
 * `assert.ok(a.score < b.score)` compares two arrays with JavaScript's `<`,
 * which compares their string forms (`jsLess`).
 */
class CompletionModelTest extends TestCase {

    public static function createSuggestItem(label:EitherType<String, CompletionItemLabel>, overwriteBefore:Int, ?kind:Null<cityscape.common.languages.CompletionItemKind>, incomplete:Bool = false, ?position:IPosition, ?sortText:String, ?filterText:String):cityscape.contrib.suggest.view.Suggest.CompletionItem {
        if (position == null) {
            position = {lineNumber: 1, column: 1};
        }
        final l:Any = label;
        final itemKind:cityscape.common.languages.CompletionItemKind = kind != null ? kind : cityscape.common.languages.CompletionItemKind.Property;
        final suggestion:cityscape.common.Languages.CompletionItem = {
            label: label,
            sortText: sortText,
            filterText: filterText,
            range: ({startLineNumber: position.lineNumber, startColumn: position.column - overwriteBefore, endLineNumber: position.lineNumber, endColumn: position.column} : cityscape.common.core.Range.IRange),
            insertText: Std.isOfType(l, std.String) ? (l : std.String) : (l : CompletionItemLabel).label,
            kind: itemKind
        };
        final container:CompletionList = {
            incomplete: incomplete,
            suggestions: [suggestion]
        };
        final provider = new NullCompletionProvider();

        return new cityscape.contrib.suggest.view.Suggest.CompletionItem(Position.lift(position), suggestion, container, provider);
    }

    static function jsLess(a:cityscape.base.common.Filters.FuzzyScore, b:cityscape.base.common.Filters.FuzzyScore):Bool {
        return a.toArray().join(',') < b.toArray().join(',');
    }

    var model:CompletionModel;

    static function defaultSuggest():InternalSuggestOptions {
        return EditorOptions.suggest.defaultValue;
    }

    override public function setup():Void {

        model = new CompletionModel([
            createSuggestItem('foo', 3),
            createSuggestItem('Foo', 3),
            createSuggestItem('foo', 2),
        ], 1, {
            leadingLineContent: 'foo',
            characterCountDelta: 0
        }, WordDistance.None, defaultSuggest(), 'inline', null);
    }

    function testFilteringCached() {

        final itemsNow = model.items;
        var itemsThen = model.items;
        assertTrue(itemsNow == itemsThen);

        // still the same context
        model.lineContext = {leadingLineContent: 'foo', characterCountDelta: 0};
        itemsThen = model.items;
        assertTrue(itemsNow == itemsThen);

        // different context, refilter
        model.lineContext = {leadingLineContent: 'foo1', characterCountDelta: 1};
        itemsThen = model.items;
        assertTrue(itemsNow != itemsThen);
    }

    function testCompleteIncomplete() {

        assertEquals(0, model.getIncompleteProvider().length);

        final incompleteModel = new CompletionModel([
            createSuggestItem('foo', 3, null, true),
            createSuggestItem('foo', 2),
        ], 1, {
            leadingLineContent: 'foo',
            characterCountDelta: 0
        }, WordDistance.None, defaultSuggest(), 'inline', null);
        assertEquals(1, incompleteModel.getIncompleteProvider().length);
    }

    function testFuzzyMatchingOfSnippetsStoppedWorkingWithInlineSnippetSuggestions49895() {
        final completeItem1 = createSuggestItem('foobar1', 1, null, false, {lineNumber: 1, column: 2});
        final completeItem2 = createSuggestItem('foobar2', 1, null, false, {lineNumber: 1, column: 2});
        final completeItem3 = createSuggestItem('foobar3', 1, null, false, {lineNumber: 1, column: 2});
        final completeItem4 = createSuggestItem('foobar4', 1, null, false, {lineNumber: 1, column: 2});
        final completeItem5 = createSuggestItem('foobar5', 1, null, false, {lineNumber: 1, column: 2});
        final incompleteItem1 = createSuggestItem('foofoo1', 1, null, true, {lineNumber: 1, column: 2});

        final model = new CompletionModel(
            [
                completeItem1,
                completeItem2,
                completeItem3,
                completeItem4,
                completeItem5,
                incompleteItem1,
            ], 2, {leadingLineContent: 'f', characterCountDelta: 0}, WordDistance.None, defaultSuggest(), 'inline', null
        );
        assertEquals(1, model.getIncompleteProvider().length);
        assertEquals(6, model.items.length);
    }

    function testProperCurrentWordWhenLength0_16380() {

        model = new CompletionModel([
            createSuggestItem('    </div', 4),
            createSuggestItem('a', 0),
            createSuggestItem('p', 0),
            createSuggestItem('    </tag', 4),
            createSuggestItem('    XYZ', 4),
        ], 1, {
            leadingLineContent: '   <',
            characterCountDelta: 0
        }, WordDistance.None, defaultSuggest(), 'inline', null);

        assertEquals(4, model.items.length);

        final items = model.items;
        assertEquals('    </div', items[0].completion.label);
        assertEquals('    </tag', items[1].completion.label);
        assertEquals('a', items[2].completion.label);
        assertEquals('p', items[3].completion.label);
    }

    function testKeepSnippetSortingWithPrefixTop25495() {

        model = new CompletionModel([
            createSuggestItem('Snippet1', 1, cityscape.common.languages.CompletionItemKind.Snippet),
            createSuggestItem('tnippet2', 1, cityscape.common.languages.CompletionItemKind.Snippet),
            createSuggestItem('semver', 1, cityscape.common.languages.CompletionItemKind.Property),
        ], 1, {
            leadingLineContent: 's',
            characterCountDelta: 0
        }, WordDistance.None, defaultSuggest(), 'top', null);

        assertEquals(2, model.items.length);
        final a = model.items[0];
        final b = model.items[1];
        assertEquals('Snippet1', a.completion.label);
        assertEquals('semver', b.completion.label);
        assertTrue(jsLess(a.score, b.score)); // snippet really promoted

    }

    function testKeepSnippetSortingWithPrefixBottom25495() {

        model = new CompletionModel([
            createSuggestItem('snippet1', 1, cityscape.common.languages.CompletionItemKind.Snippet),
            createSuggestItem('tnippet2', 1, cityscape.common.languages.CompletionItemKind.Snippet),
            createSuggestItem('Semver', 1, cityscape.common.languages.CompletionItemKind.Property),
        ], 1, {
            leadingLineContent: 's',
            characterCountDelta: 0
        }, WordDistance.None, defaultSuggest(), 'bottom', null);

        assertEquals(2, model.items.length);
        final a = model.items[0];
        final b = model.items[1];
        assertEquals('Semver', a.completion.label);
        assertEquals('snippet1', b.completion.label);
        assertTrue(jsLess(a.score, b.score)); // snippet really demoted
    }

    function testKeepSnippetSortingWithPrefixInline25495() {

        model = new CompletionModel([
            createSuggestItem('snippet1', 1, cityscape.common.languages.CompletionItemKind.Snippet),
            createSuggestItem('tnippet2', 1, cityscape.common.languages.CompletionItemKind.Snippet),
            createSuggestItem('Semver', 1),
        ], 1, {
            leadingLineContent: 's',
            characterCountDelta: 0
        }, WordDistance.None, defaultSuggest(), 'inline', null);

        assertEquals(2, model.items.length);
        final a = model.items[0];
        final b = model.items[1];
        assertEquals('snippet1', a.completion.label);
        assertEquals('Semver', b.completion.label);
        assertTrue(jsLess(b.score, a.score)); // snippet really demoted
    }

    function testFilterTextSeemsIgnoredInAutocompletion26874() {

        final item1 = createSuggestItem('Map - java.util', 1, null, false, null, null, 'Map');
        final item2 = createSuggestItem('Map - java.util', 1);

        model = new CompletionModel([item1, item2], 1, {
            leadingLineContent: 'M',
            characterCountDelta: 0
        }, WordDistance.None, defaultSuggest(), 'inline', null);

        assertEquals(2, model.items.length);

        model.lineContext = {
            leadingLineContent: 'Map ',
            characterCountDelta: 3
        };
        assertEquals(1, model.items.length);
    }

    function testVscode112NoLongerObeysSortTextInCompletionItemsFromLanguageServer26096() {

        final item1 = createSuggestItem('<- groups', 2, cityscape.common.languages.CompletionItemKind.Property, false, {lineNumber: 1, column: 3}, '00002', '  groups');
        final item2 = createSuggestItem('source', 0, cityscape.common.languages.CompletionItemKind.Property, false, {lineNumber: 1, column: 3}, '00001', 'source');
        final items = [item1, item2];
        haxe.ds.ArraySort.sort(items, SuggestUtils.getSuggestionComparator(SnippetSortOrder.Inline));

        model = new CompletionModel(items, 3, {
            leadingLineContent: '  ',
            characterCountDelta: 0
        }, WordDistance.None, defaultSuggest(), 'inline', null);

        assertEquals(2, model.items.length);

        final first = model.items[0];
        final second = model.items[1];
        assertEquals('source', first.completion.label);
        assertEquals('<- groups', second.completion.label);
    }

    function testCompletionItemSortingBrokenWhenUsingLabelDetails153026() {
        final itemZZZ = createSuggestItem(({label: 'ZZZ'} : CompletionItemLabel), 0, cityscape.common.languages.CompletionItemKind.Operator, false);
        final itemAAA = createSuggestItem(({label: 'AAA'} : CompletionItemLabel), 0, cityscape.common.languages.CompletionItemKind.Operator, false);
        final itemIII = createSuggestItem('III', 0, cityscape.common.languages.CompletionItemKind.Operator, false);

        final cmp = SuggestUtils.getSuggestionComparator(SnippetSortOrder.Inline);
        final actual = [itemZZZ, itemAAA, itemIII];
        haxe.ds.ArraySort.sort(actual, cmp);

        assertTrue(actual[0] == itemAAA && actual[1] == itemIII && actual[2] == itemZZZ);
    }

    function testScoreOnlyFilteredItemsWhenTypingMoreScoreAllWhenTypingLess() {
        model = new CompletionModel([
            createSuggestItem('console', 0),
            createSuggestItem('co_new', 0),
            createSuggestItem('bar', 0),
            createSuggestItem('car', 0),
            createSuggestItem('foo', 0),
        ], 1, {
            leadingLineContent: '',
            characterCountDelta: 0
        }, WordDistance.None, defaultSuggest(), 'inline', null);

        assertEquals(5, model.items.length);

        // narrow down once
        model.lineContext = {leadingLineContent: 'c', characterCountDelta: 1};
        assertEquals(3, model.items.length);

        // query gets longer, narrow down the narrow-down'ed-set from before
        model.lineContext = {leadingLineContent: 'cn', characterCountDelta: 2};
        assertEquals(2, model.items.length);

        // query gets shorter, refilter everything
        model.lineContext = {leadingLineContent: '', characterCountDelta: 0};
        assertEquals(5, model.items.length);
    }

    function testHaveMoreRelaxedSuggestMatchingAlgorithm15419() {
        model = new CompletionModel([
            createSuggestItem('result', 0),
            createSuggestItem('replyToUser', 0),
            createSuggestItem('randomLolut', 0),
            createSuggestItem('car', 0),
            createSuggestItem('foo', 0),
        ], 1, {
            leadingLineContent: '',
            characterCountDelta: 0
        }, WordDistance.None, defaultSuggest(), 'inline', null);

        // query gets longer, narrow down the narrow-down'ed-set from before
        model.lineContext = {leadingLineContent: 'rlut', characterCountDelta: 4};
        assertEquals(3, model.items.length);

        final first = model.items[0];
        final second = model.items[1];
        final third = model.items[2];
        assertEquals('result', first.completion.label); // best with `rult`
        assertEquals('replyToUser', second.completion.label); // best with `rltu`
        assertEquals('randomLolut', third.completion.label); // best with `rlut`
    }

    function testEmmetSuggestionNotAppearingAtTheTopOfTheListInJsxFiles39518() {
        model = new CompletionModel([
            createSuggestItem('from', 0),
            createSuggestItem('form', 0),
            createSuggestItem('form:get', 0),
            createSuggestItem('testForeignMeasure', 0),
            createSuggestItem('fooRoom', 0),
        ], 1, {
            leadingLineContent: '',
            characterCountDelta: 0
        }, WordDistance.None, defaultSuggest(), 'inline', null);

        model.lineContext = {leadingLineContent: 'form', characterCountDelta: 4};
        assertEquals(5, model.items.length);
        final first = model.items[0];
        final second = model.items[1];
        final third = model.items[2];
        assertEquals('form', first.completion.label); // best with `form`
        assertEquals('form:get', second.completion.label); // best with `form`
        assertEquals('from', third.completion.label); // best with `from`
    }

}
