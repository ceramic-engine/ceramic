// New code for Cityscape (not a port): the words kept between calls by the
// word based completions give the same result as a scan of every line.
package tests.services;

import cityscape.Cityscape;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.core.WordHelper;
import cityscape.common.services.WordBasedCompletions.WordBasedCompletionItemProvider;
import testing.TestCase;

/**
 * `WordBasedCompletionItemProvider.textualSuggestCached` keeps the words of
 * each line and scans only the lines changed since the last call (like the
 * mirror models of Monaco's editor worker); its result must equal
 * `textualSuggest`, Monaco's `$textualSuggest`, which scans every line.
 */
class WordBasedCompletionsTest extends TestCase {

    var context:Cityscape;

    override public function setup():Void {
        context = new Cityscape();
    }

    override public function teardown():Void {
        for (model in context.modelService.getModels()) {
            model.dispose();
        }
    }

    function check(provider:WordBasedCompletionItemProvider, models:Array<ITextModel>, leading:Null<String>, ?pos:haxe.PosInfos):Void {
        final expected = WordBasedCompletionItemProvider.textualSuggest(models, leading, WordHelper.DEFAULT_WORD_REGEXP);
        final actual = provider.textualSuggestCached(models, leading, WordHelper.DEFAULT_WORD_REGEXP);
        assertEquals(expected.join(','), actual.join(','), null, pos);
    }

    function testNumbersAndLeadingWordAreLeftOut() {
        final provider = new WordBasedCompletionItemProvider(context);
        final model = context.modelService.createModel('foo 12 0x1F Infinity infinity bar\nfoo baz 1e3 e3 _x $$y', null);
        final words = provider.textualSuggestCached([model], 'bar', WordHelper.DEFAULT_WORD_REGEXP);
        // Number('Infinity') is a number, Number('infinity') is not
        assertEquals('foo,infinity,baz,e3,_x,y', words.join(','));
        check(provider, [model], 'bar');
    }

    function testEditsKeepTheWordsInStep() {
        final provider = new WordBasedCompletionItemProvider(context);
        final lines = [for (i in 0...60) 'line$i alpha${i % 7} beta gamma${i % 3}'];
        final model = context.modelService.createModel(lines.join('\n'), null);
        final other = context.modelService.createModel('other words here\nalpha1 delta', null);
        check(provider, [model, other], null);

        var seed = 12345;
        function random(n:Int):Int {
            seed = (seed * 1103515245 + 12345) & 0x7fffffff;
            return seed % n;
        }
        final insertions = ['x', 'word', ' ', '\n', 'new\nlines here\n', 'a\r\nb', '\n\n\n\n\n\n\n\n\n\nten more\n', ''];
        for (step in 0...300) {
            final lineCount = model.getLineCount();
            final startLine = 1 + random(lineCount);
            final startColumn = 1 + random(model.getLineMaxColumn(startLine));
            final endLine = Std.int(Math.min(lineCount, startLine + random(3)));
            final endColumn = endLine == startLine ? startColumn + random(model.getLineMaxColumn(startLine) - startColumn + 1) : 1 + random(model.getLineMaxColumn(endLine));
            final text = insertions[random(insertions.length)];
            switch random(4) {
                case 0:
                    // two edits at once (sorted from the end by the model)
                    final otherLine = 1 + random(lineCount);
                    if (otherLine < startLine || otherLine > endLine) {
                        model.applyEdits([
                            {range: new Range(startLine, startColumn, endLine, endColumn), text: text},
                            {range: new Range(otherLine, 1, otherLine, 1), text: 'zz$step\n'}
                        ]);
                    }
                case 1:
                    model.pushEditOperations([], [{range: new Range(startLine, startColumn, endLine, endColumn), text: text}], _ -> null);
                    if (random(3) == 0) {
                        model.undo();
                    }
                case _:
                    model.applyEdits([{range: new Range(startLine, startColumn, endLine, endColumn), text: text}]);
            }
            if (step % 3 == 0) {
                check(provider, [model, other], step % 2 == 0 ? 'beta' : null);
            }
        }
        check(provider, [model, other], null);

        model.setValue('replaced\nall of it 42');
        check(provider, [model, other], null);
        assertEquals('replaced,all,of,it,other,words,here,alpha1,delta', provider.textualSuggestCached([model, other], null, WordHelper.DEFAULT_WORD_REGEXP).join(','));
    }

    function testDisposedModelsAreForgotten() {
        final provider = new WordBasedCompletionItemProvider(context);
        final a = context.modelService.createModel('one two', null);
        final b = context.modelService.createModel('three', null);
        check(provider, [a, b], null);
        assertEquals(2, provider.cachedModelCount());
        a.dispose();
        assertEquals(1, provider.cachedModelCount());
        b.dispose();
        assertEquals(0, provider.cachedModelCount());
    }

}
