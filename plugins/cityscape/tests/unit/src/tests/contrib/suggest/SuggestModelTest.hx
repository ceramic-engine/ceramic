// Ported from vscode src/vs/editor/contrib/suggest/test/browser/suggestModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.suggest;

import cityscape.Cityscape;
import cityscape.base.common.Event;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.contrib.snippet.view.SnippetController2;
import cityscape.contrib.suggest.view.SuggestModel;
import cityscape.view.CoreCommands.CoreEditingCommands;
import testing.TestCase;
import testing.TestCodeEditor;
import tests.contrib.suggest.SuggestTest.FixedCompletionProvider;

/**
 * suite('SuggestModel - Context') and suite('SuggestModel -
 * TriggerAndCancelOracle'), the headless tests.
 *
 * The events come synchronously here (providers answer at once), except
 * the quick suggestions, which wait for `quickSuggestionsDelay`:
 * `assertEvent` runs the pending quick suggest (`_flushQuickSuggest`)
 * when the event did not come during the action, instead of waiting.
 * The word based completions of the context are off (vscode's test
 * services have none).
 *
 * Not ported: 'shouldAutoTrigger at embedded language boundaries' (an
 * embedded language tokenizer), and the tests after #36491 (the
 * completion code action #39893, the snippet #43523 and the details #47988
 * tests need the full suggest controller, and the later ones the inline
 * completions or vscode's configuration service).
 */
class SuggestModelTest extends TestCase {

    var context:Cityscape;
    var model:TextModel;
    var oracles:Array<{oracle:SuggestModel, editor:TestCodeEditor}> = [];

    override public function setup():Void {
        context = new Cityscape();
        context.wordBasedSuggestions = 'off';
        model = new TextModel('abc def', 'plaintext', TextModel.DEFAULT_CREATION_OPTIONS, Uri.parse('test:somefile.ttt'), context);
    }

    override public function teardown():Void {
        for (o in oracles) {
            o.oracle.dispose();
            o.editor.dispose();
        }
        oracles = [];
        model.dispose();
    }

    static function getDefaultSuggestRange(model:ITextModel, position:Position):Range {
        final wordUntil = model.getWordUntilPosition(position);
        return new Range(position.lineNumber, wordUntil.startColumn, position.lineNumber, wordUntil.endColumn);
    }

    static final alwaysEmptySupport = new FixedCompletionProvider(pos -> {
        return {
            incomplete: false,
            suggestions: []
        };
    });

    var alwaysSomethingSupport:FixedCompletionProvider;

    function register(provider:CompletionItemProvider):Void {
        context.languageFeaturesService.completionProvider.register(({scheme: 'test'} : cityscape.common.LanguageSelector.LanguageFilter), provider);
    }

    function createMockEditor():TestCodeEditor {
        final editor = new TestCodeEditor(context, model, {}, context.editorExtensions.getSomeEditorContributions([SnippetController2.ID]));
        editor.getViewModel().setHasFocus(true);
        return editor;
    }

    function withOracle(callback:(model:SuggestModel, editor:TestCodeEditor) -> Void):Void {
        final editor = createMockEditor();
        final oracle = new SuggestModel(editor);
        oracles.push({oracle: oracle, editor: editor});
        callback(oracle, editor);
    }

    function assertEvent<E>(event:Event<E>, action:() -> Void, check:(e:E) -> Void, oracle:SuggestModel, ?pos:haxe.PosInfos):Void {
        var received:E = null; // not Null<E>: a captured Null<E> is read as object on C#
        var fired = false;
        var sub:Null<cityscape.base.common.Lifecycle.IDisposable> = null;
        sub = event(e -> {
            if (!fired) {
                fired = true;
                received = e;
                sub.dispose();
            }
        });
        action();
        if (!fired) {
            oracle._flushQuickSuggest();
        }
        assertTrue(fired, 'event fired', pos);
        if (fired) {
            check(received);
        }
        else {
            sub.dispose();
        }
    }

    function typeText(editor:TestCodeEditor, text:String):Void {
        editor.trigger('keyboard', 'type', {text: text});
    }

    function testContextShouldAutoTrigger() {
        final model = new TextModel('Das Pferd frisst keinen Gurkensalat - Philipp Reis 1861.\nWer hat\'s erfunden?', 'plaintext', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        final assertAutoTrigger = (offset:Int, expected:Bool, message:String) -> {
            final pos = model.getPositionAt(offset);
            final editor = new TestCodeEditor(context, model, {});
            editor.setPosition(pos);
            assertEquals(expected, SuggestLineContext.shouldAutoTrigger(editor), message);
            editor.dispose();
        };

        assertAutoTrigger(3, true, 'end of word, Das|');
        assertAutoTrigger(4, false, 'no word Das |');
        assertAutoTrigger(1, true, 'typing a single character before a word: D|as');
        assertAutoTrigger(55, false, 'number, 1861|');
        model.dispose();
    }

    function testEventsCancelTrigger() {
        withOracle((model, editor) -> {

            // Without providers the request ends at once (Monaco's ends a
            // turn later): the automatic trigger finds nothing and cancels
            // during `trigger`, where Monaco's test cancels it explicitly
            var cancel:Null<ICancelEvent> = null;
            final sub = model.onDidCancel(e -> cancel = e);
            assertEvent(model.onDidTrigger, () -> {
                model.trigger({auto: true});
            }, event -> {
                assertEquals(true, event.auto);
            }, model);
            model.cancel();
            sub.dispose();
            assertNotNull(cancel);
            assertEquals(false, cancel.retrigger);

            assertEvent(model.onDidTrigger, () -> {
                model.trigger({auto: true});
            }, event -> {
                assertEquals(true, event.auto);
            }, model);

            assertEvent(model.onDidTrigger, () -> {
                model.trigger({auto: false});
            }, event -> {
                assertEquals(false, event.auto);
            }, model);
        });
    }

    function testEventsSuggestEmpty() {

        register(alwaysEmptySupport);

        withOracle((model, editor) -> {
            assertEvent(model.onDidCancel, () -> {
                model.trigger({auto: true});
            }, event -> {
                assertEquals(false, event.retrigger);
            }, model);
            assertEvent(model.onDidSuggest, () -> {
                model.trigger({auto: false});
            }, event -> {
                assertEquals(false, event.triggerOptions.auto);
                assertEquals(false, event.isFrozen);
                assertEquals(0, event.completionModel.items.length);
            }, model);
        });
    }

    function makeAlwaysSomething():FixedCompletionProvider {
        var provider:Null<FixedCompletionProvider> = null;
        provider = new FixedCompletionProvider(pos -> {
            return {
                incomplete: false,
                suggestions: [{
                    label: model.getWordUntilPosition(pos).word,
                    kind: cityscape.common.languages.CompletionItemKind.Property,
                    insertText: 'foofoo',
                    range: getDefaultSuggestRange(model, pos)
                }]
            };
        });
        return provider;
    }

    function testTriggerOnType() {

        alwaysSomethingSupport = makeAlwaysSomething();
        register(alwaysSomethingSupport);

        withOracle((model, editor) -> {
            assertEvent(model.onDidSuggest, () -> {
                editor.setPosition({lineNumber: 1, column: 4});
                typeText(editor, 'd');

            }, event -> {
                assertEquals(true, event.triggerOptions.auto);
                assertEquals(1, event.completionModel.items.length);
                final first = event.completionModel.items[0];

                assertTrue(first.provider == alwaysSomethingSupport);
            }, model);
        });
    }

    function test17400KeepFilteringSuggestModelTsAfterSpace() {

        register(new FixedCompletionProvider(pos -> {
            return {
                incomplete: false,
                suggestions: [{
                    label: 'My Table',
                    kind: cityscape.common.languages.CompletionItemKind.Property,
                    insertText: 'My Table',
                    range: getDefaultSuggestRange(model, pos)
                }]
            };
        }));

        model.setValue('');

        withOracle((model, editor) -> {

            assertEvent(model.onDidSuggest, () -> {
                // make sure completionModel starts here!
                model.trigger({auto: true});
            }, event -> {

                assertEvent(model.onDidSuggest, () -> {
                    editor.setPosition({lineNumber: 1, column: 1});
                    typeText(editor, 'My');

                }, event -> {
                    assertEquals(true, event.triggerOptions.auto);
                    assertEquals(1, event.completionModel.items.length);
                    final first = event.completionModel.items[0];
                    assertEquals('My Table', first.completion.label);

                    assertEvent(model.onDidSuggest, () -> {
                        editor.setPosition({lineNumber: 1, column: 3});
                        typeText(editor, ' ');

                    }, event -> {
                        assertEquals(true, event.triggerOptions.auto);
                        assertEquals(1, event.completionModel.items.length);
                        final first = event.completionModel.items[0];
                        assertEquals('My Table', first.completion.label);
                    }, model);
                }, model);
            }, model);
        });
    }

    function test21484TriggerCharacterAlwaysForceANewCompletionSession() {

        register(new FixedCompletionProvider(pos -> {
            return {
                incomplete: false,
                suggestions: [{
                    label: 'foo.bar',
                    kind: cityscape.common.languages.CompletionItemKind.Property,
                    insertText: 'foo.bar',
                    range: Range.fromPositions(pos.with(null, 1), pos)
                }]
            };
        }));

        final dotProvider = new FixedCompletionProvider(pos -> {
            return {
                incomplete: false,
                suggestions: [{
                    label: 'boom',
                    kind: cityscape.common.languages.CompletionItemKind.Property,
                    insertText: 'boom',
                    range: Range.fromPositions(
                        pos.delta(0, model.getLineContent(pos.lineNumber).charAt(pos.column - 2) == '.' ? 0 : -1),
                        pos
                    )
                }]
            };
        });
        @:privateAccess dotProvider.triggerCharacters = ['.'];
        register(dotProvider);

        model.setValue('');

        withOracle((model, editor) -> {

            assertEvent(model.onDidSuggest, () -> {
                editor.setPosition({lineNumber: 1, column: 1});
                typeText(editor, 'foo');

            }, event -> {
                assertEquals(true, event.triggerOptions.auto);
                assertEquals(1, event.completionModel.items.length);
                final first = event.completionModel.items[0];
                assertEquals('foo.bar', first.completion.label);

            }, model);

            // Monaco gets the synchronous refilter (foo.bar) first, then the
            // completions of the trigger character: both come during the typing
            final events:Array<ISuggestEvent> = [];
            final sub = model.onDidSuggest(e -> events.push(e));
            typeText(editor, '.');
            sub.dispose();
            assertTrue(events.length >= 1);
            // SYNC
            assertEquals(true, events[0].triggerOptions.auto);
            assertEquals(1, events[0].completionModel.items.length);
            assertEquals('foo.bar', events[0].completionModel.items[0].completion.label);
            // ASYNC
            final last = events[events.length - 1];
            assertEquals(true, last.triggerOptions.auto);
            assertEquals(2, last.completionModel.items.length);
            assertEquals('foo.bar', last.completionModel.items[0].completion.label);
            assertEquals('boom', last.completionModel.items[1].completion.label);
        });
    }

    function testIncompleteSuggestionResultsCauseReTriggeringWhenTypingWOFurtherContext28400_1_2() {

        register(new FixedCompletionProvider(pos -> {
            return {
                incomplete: true,
                suggestions: [{
                    label: 'foo',
                    kind: cityscape.common.languages.CompletionItemKind.Property,
                    insertText: 'foo',
                    range: Range.fromPositions(pos.with(null, 1), pos)
                }]
            };
        }));

        withOracle((model, editor) -> {

            editor.getModel().setValue('foo');
            editor.setPosition({lineNumber: 1, column: 4});

            assertEvent(model.onDidSuggest, () -> {
                model.trigger({auto: false});
            }, event -> {
                assertEquals(false, event.triggerOptions.auto);
                assertEquals(1, event.completionModel.getIncompleteProvider().length);
                assertEquals(1, event.completionModel.items.length);

                assertEvent(model.onDidCancel, () -> {
                    typeText(editor, ';');
                }, event -> {
                    assertEquals(false, event.retrigger);
                }, model);
            }, model);
        });
    }

    function testIncompleteSuggestionResultsCauseReTriggeringWhenTypingWOFurtherContext28400_2_2() {

        register(new FixedCompletionProvider(pos -> {
            return {
                incomplete: true,
                suggestions: [{
                    label: 'foo;',
                    kind: cityscape.common.languages.CompletionItemKind.Property,
                    insertText: 'foo',
                    range: Range.fromPositions(pos.with(null, 1), pos)
                }]
            };
        }));

        withOracle((model, editor) -> {

            editor.getModel().setValue('foo');
            editor.setPosition({lineNumber: 1, column: 4});

            assertEvent(model.onDidSuggest, () -> {
                model.trigger({auto: false});
            }, event -> {
                assertEquals(false, event.triggerOptions.auto);
                assertEquals(1, event.completionModel.getIncompleteProvider().length);
                assertEquals(1, event.completionModel.items.length);

                assertEvent(model.onDidSuggest, () -> {
                    // while we cancel incrementally enriching the set of
                    // completions we still filter against those that we have
                    // until now
                    typeText(editor, ';');
                }, event -> {
                    assertEquals(false, event.triggerOptions.auto);
                    assertEquals(1, event.completionModel.getIncompleteProvider().length);
                    assertEquals(1, event.completionModel.items.length);

                }, model);
            }, model);
        });
    }

    function testTriggerCharacterIsProvidedInSuggestContext() {
        var triggerCharacter = '';
        final provider = new TriggerCharacterProvider(this, c -> triggerCharacter = c);
        register(provider);

        model.setValue('');

        withOracle((model, editor) -> {

            assertEvent(model.onDidSuggest, () -> {
                editor.setPosition({lineNumber: 1, column: 1});
                typeText(editor, 'foo.');
            }, event -> {
                assertEquals('.', triggerCharacter);
            }, model);
        });
    }

    @:allow(tests.contrib.suggest)
    function checkTriggerKind(kind:CompletionTriggerKind):Void {
        assertEquals(CompletionTriggerKind.TriggerCharacter, kind);
    }

    function testMacPressAndHoldAccentCharacterInsertionDoesNotUpdateSuggestions35269() {
        register(new FixedCompletionProvider(pos -> {
            return {
                incomplete: true,
                suggestions: [{
                    label: 'abc',
                    kind: cityscape.common.languages.CompletionItemKind.Property,
                    insertText: 'abc',
                    range: Range.fromPositions(pos.with(null, 1), pos)
                }, {
                    label: 'äbc',
                    kind: cityscape.common.languages.CompletionItemKind.Property,
                    insertText: 'äbc',
                    range: Range.fromPositions(pos.with(null, 1), pos)
                }]
            };
        }));

        model.setValue('');
        withOracle((model, editor) -> {

            assertEvent(model.onDidSuggest, () -> {
                editor.setPosition({lineNumber: 1, column: 1});
                typeText(editor, 'a');
            }, event -> {
                assertEquals(1, event.completionModel.items.length);
                assertEquals('abc', event.completionModel.items[0].completion.label);

                assertEvent(model.onDidSuggest, () -> {
                    editor.executeEdits('test', [EditOperation.replace(new Range(1, 1, 1, 2), 'ä')]);

                }, event -> {
                    // suggest model changed to äbc
                    assertEquals(1, event.completionModel.items.length);
                    assertEquals('äbc', event.completionModel.items[0].completion.label);

                }, model);
            }, model);
        });
    }

    function testBackspaceShouldNotAlwaysCancelCodeCompletion36491() {
        alwaysSomethingSupport = makeAlwaysSomething();
        register(alwaysSomethingSupport);

        withOracle((model, editor) -> {
            assertEvent(model.onDidSuggest, () -> {
                editor.setPosition({lineNumber: 1, column: 4});
                typeText(editor, 'd');

            }, event -> {
                assertEquals(true, event.triggerOptions.auto);
                assertEquals(1, event.completionModel.items.length);
                final first = event.completionModel.items[0];

                assertTrue(first.provider == alwaysSomethingSupport);
            }, model);

            assertEvent(model.onDidSuggest, () -> {
                CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);

            }, event -> {
                assertEquals(true, event.triggerOptions.auto);
                assertEquals(1, event.completionModel.items.length);
                final first = event.completionModel.items[0];

                assertTrue(first.provider == alwaysSomethingSupport);
            }, model);
        });
    }

}

/**
 * The provider of 'Trigger character is provided in suggest context'.
 */
private class TriggerCharacterProvider implements CompletionItemProvider {
    public var _debugDisplayName(default, null):Null<String> = 'test';
    public var triggerCharacters(default, null):Null<Array<String>> = ['.'];
    public var resolveCompletionItem(default, null):Null<(item:cityscape.common.Languages.CompletionItem, token:cityscape.base.common.Cancellation.CancellationToken, resolve:(item:Null<cityscape.common.Languages.CompletionItem>) -> Void) -> Void> = null;

    final test:SuggestModelTest;
    final onTrigger:(c:String) -> Void;

    public function new(test:SuggestModelTest, onTrigger:(c:String) -> Void) {
        this.test = test;
        this.onTrigger = onTrigger;
    }

    public function provideCompletionItems(model:ITextModel, pos:Position, context:CompletionContext, token:cityscape.base.common.Cancellation.CancellationToken, resolve:(list:Null<CompletionList>) -> Void):Void {
        test.checkTriggerKind(context.triggerKind);
        onTrigger(context.triggerCharacter);
        resolve({
            incomplete: false,
            suggestions: [
                {
                    label: 'foo.bar',
                    kind: cityscape.common.languages.CompletionItemKind.Property,
                    insertText: 'foo.bar',
                    range: Range.fromPositions(pos.with(null, 1), pos)
                }
            ]
        });
    }
}
