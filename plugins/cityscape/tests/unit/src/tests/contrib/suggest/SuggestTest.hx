// Ported from vscode src/vs/editor/contrib/suggest/test/browser/suggest.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.suggest;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Uri;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.contrib.suggest.view.Suggest;
import testing.TestCase;

/**
 * A completion provider answering with fixed suggestions (the object
 * literals of the tests): `make` builds them at the requested position.
 */
class FixedCompletionProvider implements CompletionItemProvider {
    public var _debugDisplayName(default, null):Null<String> = 'test';
    public var triggerCharacters(default, null):Null<Array<String>> = [];
    public var resolveCompletionItem(default, null):Null<(item:cityscape.common.Languages.CompletionItem, token:CancellationToken, resolve:(item:Null<cityscape.common.Languages.CompletionItem>) -> Void) -> Void> = null;

    final make:(pos:Position) -> Null<CompletionList>;

    public function new(make:(pos:Position) -> Null<CompletionList>) {
        this.make = make;
    }

    public function provideCompletionItems(model:ITextModel, position:Position, context:CompletionContext, token:CancellationToken, resolve:(list:Null<CompletionList>) -> Void):Void {
        resolve(make(position));
    }
}

/**
 * suite('Suggest'). The `async` tests run synchronously: the providers
 * answer at once and `Promise` settles at once.
 */
class SuggestTest extends TestCase {

    var model:TextModel;
    var registration:IDisposable;
    var registry:LanguageFeatureRegistry<CompletionItemProvider>;

    override public function setup():Void {
        registry = new LanguageFeatureRegistry();
        model = tests.TestTextModel.createTextModel('FOO\nbarBAR\nfoo', // vscode's 'bar\BAR' (`\B` is `B` in JavaScript)
 null, null, Uri.parse('foo:bar/path'));
        registration = registry.register(({pattern: 'bar/path', scheme: 'foo'} : cityscape.common.LanguageSelector.LanguageFilter), new FixedCompletionProvider(pos -> {
            return {
                incomplete: false,
                suggestions: [{
                    label: 'aaa',
                    kind: cityscape.common.languages.CompletionItemKind.Snippet,
                    insertText: 'aaa',
                    range: Range.fromPositions(pos)
                }, {
                    label: 'zzz',
                    kind: cityscape.common.languages.CompletionItemKind.Snippet,
                    insertText: 'zzz',
                    range: Range.fromPositions(pos)
                }, {
                    label: 'fff',
                    kind: cityscape.common.languages.CompletionItemKind.Property,
                    insertText: 'fff',
                    range: Range.fromPositions(pos)
                }]
            };
        }));
    }

    override public function teardown():Void {
        registration.dispose();
        model.dispose();
    }

    function provide(options:CompletionOptions, ?position:Position):CompletionItemModel {
        var result:Null<CompletionItemModel> = null;
        SuggestUtils.provideSuggestionItems(registry, model, position != null ? position : new Position(1, 1), options).done(r -> result = r);
        assertNotNull(result, 'resolved synchronously');
        return result;
    }

    function testSortSnippetInline() {
        final result = provide(new CompletionOptions(SnippetSortOrder.Inline));
        final items = result.items;
        assertEquals(3, items.length);
        assertEquals('aaa', items[0].completion.label);
        assertEquals('fff', items[1].completion.label);
        assertEquals('zzz', items[2].completion.label);
        result.disposable.dispose();
    }

    function testSortSnippetTop() {
        final result = provide(new CompletionOptions(SnippetSortOrder.Top));
        final items = result.items;
        assertEquals(3, items.length);
        assertEquals('aaa', items[0].completion.label);
        assertEquals('zzz', items[1].completion.label);
        assertEquals('fff', items[2].completion.label);
        result.disposable.dispose();
    }

    function testSortSnippetBottom() {
        final result = provide(new CompletionOptions(SnippetSortOrder.Bottom));
        final items = result.items;
        assertEquals(3, items.length);
        assertEquals('fff', items[0].completion.label);
        assertEquals('aaa', items[1].completion.label);
        assertEquals('zzz', items[2].completion.label);
        result.disposable.dispose();
    }

    function testSortSnippetNone() {
        final result = provide(new CompletionOptions(cityscape.contrib.suggest.view.SnippetSortOrder.Bottom, [cityscape.common.languages.CompletionItemKind.Snippet]));
        final items = result.items;
        assertEquals(1, items.length);
        assertEquals('fff', items[0].completion.label);
        result.disposable.dispose();
    }

    function testOnlyFrom() {

        final foo = new FixedCompletionProvider(pos -> {
            return {
                incomplete: false,
                suggestions: [{
                    label: 'jjj',
                    kind: cityscape.common.languages.CompletionItemKind.Property,
                    insertText: 'jjj'
                }]
            };
        });
        final registration = registry.register(({pattern: 'bar/path', scheme: 'foo'} : cityscape.common.LanguageSelector.LanguageFilter), foo);

        final result = provide(new CompletionOptions(cityscape.contrib.suggest.view.SnippetSortOrder.Bottom, null, [foo]));
        registration.dispose();

        assertEquals(1, result.items.length);
        assertTrue(result.items[0].provider == foo);
        result.disposable.dispose();
    }

    function testCtrlSpaceCompletionsStoppedWorkingWithTheLatestInsiders97650() {

        final foo = new FixedCompletionProvider(pos -> {
            return {
                suggestions: [{
                    label: 'one',
                    kind: cityscape.common.languages.CompletionItemKind.Class,
                    insertText: 'one',
                    range: ({
                        insert: new Range(0, 0, 0, 0),
                        replace: new Range(0, 0, 0, 10)
                    } : CompletionItemRanges)
                }, {
                    label: 'two',
                    kind: cityscape.common.languages.CompletionItemKind.Class,
                    insertText: 'two',
                    range: ({
                        insert: new Range(0, 0, 0, 0),
                        replace: new Range(0, 1, 0, 10)
                    } : CompletionItemRanges)
                }]
            };
        });

        final registration = registry.register(({pattern: 'bar/path', scheme: 'foo'} : cityscape.common.LanguageSelector.LanguageFilter), foo);
        final result = provide(new CompletionOptions(cityscape.contrib.suggest.view.SnippetSortOrder.Bottom, null, [foo]), new Position(0, 0));
        registration.dispose();

        final items = result.items;
        assertEquals(2, items.length);
        final a = items[0];
        final b = items[1];

        assertEquals('one', a.completion.label);
        assertEquals(false, a.isInvalid);
        assertEquals('two', b.completion.label);
        assertEquals(true, b.isInvalid);
        result.disposable.dispose();
    }

}
