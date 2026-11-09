// Ported from vscode src/vs/editor/contrib/parameterHints/test/browser/parameterHintsModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.parameterHints;

// Classes of this module:
// - ParameterHintsModelTest
//
// All the tests are ported. vscode's `runWithFakedTimers` is
// `testing.TimeTravelScheduler`: the virtual clock runs the timeouts
// until the test's `done` (vscode's awaited promise) is reached, and the
// test checks it was. Providers answer through their `resolve` callback,
// at once or from a timeout (vscode's returned promises). The two tests
// vscode names 'Provider should be retriggered if already active' are
// `testProviderShouldBeRetriggeredIfAlreadyActive` and
// `testProviderShouldBeRetriggeredIfAlreadyActive2`.

import cityscape.base.common.Async;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.common.EditorCommon.Handler;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.contrib.parameterHints.view.ParameterHintsModel;
import testing.TestCase;
import testing.TestCodeEditor;
import testing.TimeTravelScheduler;
import tests.TestTextModel;

private class TestSignatureHelpProvider implements SignatureHelpProvider {
    public var signatureHelpTriggerCharacters(default, null):Null<Array<String>>;
    public var signatureHelpRetriggerCharacters(default, null):Null<Array<String>>;

    final provide:(model:ITextModel, position:Position, token:CancellationToken, context:SignatureHelpContext, resolve:(result:Null<SignatureHelpResult>) -> Void) -> Void;

    public function new(triggerCharacters:Array<String>, retriggerCharacters:Array<String>, provide:(model:ITextModel, position:Position, token:CancellationToken, context:SignatureHelpContext, resolve:(result:Null<SignatureHelpResult>) -> Void) -> Void) {
        this.signatureHelpTriggerCharacters = triggerCharacters;
        this.signatureHelpRetriggerCharacters = retriggerCharacters;
        this.provide = provide;
    }

    public function provideSignatureHelp(model:ITextModel, position:Position, token:CancellationToken, context:SignatureHelpContext, resolve:(result:Null<SignatureHelpResult>) -> Void):Void {
        provide(model, position, token, context, resolve);
    }
}

/**
 * suite('ParameterHintsModel')
 */
class ParameterHintsModelTest extends TestCase {

    static final mockFile = Uri.parse('test:somefile.ttt');
    static final mockFileSelector:cityscape.common.LanguageSelector.LanguageFilter = {scheme: 'test'};

    static final emptySigHelp:SignatureHelp = {
        signatures: [{
            label: 'none',
            parameters: []
        }],
        activeParameter: 0,
        activeSignature: 0
    };

    static final emptySigHelpResult:SignatureHelpResult = {
        value: emptySigHelp,
        dispose: () -> {}
    };

    var disposables:DisposableStore;
    var registry:LanguageFeatureRegistry<SignatureHelpProvider>;

    override public function setup():Void {
        disposables = new DisposableStore();
        registry = new LanguageFeatureRegistry<SignatureHelpProvider>();
    }

    override public function teardown():Void {
        disposables.dispose();
    }

    function createMockEditor(fileContents:String):TestCodeEditor {
        final textModel = TestTextModel.createTextModel(fileContents, null, null, mockFile);
        disposables.add(Lifecycle.toDisposable(() -> textModel.dispose()));
        final editor = new TestCodeEditor(textModel.context, textModel, {});
        disposables.add(Lifecycle.toDisposable(() -> editor.dispose()));
        return editor;
    }

    /**
     * Records the next hints the model fires (vscode's `getNextHint`
     * promise): `fired` once it fired, with the hints in `value`.
     */
    function getNextHint(model:ParameterHintsModel):{fired:Bool, value:Null<SignatureHelp>} {
        final result:{fired:Bool, value:Null<SignatureHelp>} = {fired: false, value: null};
        var sub:Null<IDisposable> = null;
        sub = model.onChangedHints(e -> {
            if (sub != null) {
                sub.dispose();
            }
            if (!result.fired) {
                result.fired = true;
                result.value = e;
            }
        });
        disposables.add(sub);
        return result;
    }

    function testProviderShouldGetTriggerCharacterOnType() {
        var done = false;

        final triggerChar = '(';

        final editor = createMockEditor('');
        disposables.add(new ParameterHintsModel(editor, registry));

        disposables.add(registry.register(mockFileSelector, new TestSignatureHelpProvider([triggerChar], [], (_model, _position, _token, context, resolve) -> {
            assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
            assertEquals(triggerChar, context.triggerCharacter);
            done = true;
            resolve(null);
        })));

        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', Handler.Type, {text: triggerChar});
            scheduler.runUntil(() -> done);
        });
        assertTrue(done);
    }

    function testProviderShouldBeRetriggeredIfAlreadyActive() {
        var done = false;

        final triggerChar = '(';

        final editor = createMockEditor('');
        disposables.add(new ParameterHintsModel(editor, registry));

        var invokeCount = 0;
        disposables.add(registry.register(mockFileSelector, new TestSignatureHelpProvider([triggerChar], [], (_model, _position, _token, context, resolve) -> {
            ++invokeCount;
            if (invokeCount == 1) {
                assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
                assertEquals(triggerChar, context.triggerCharacter);
                assertEquals(false, context.isRetrigger);
                assertEquals(null, context.activeSignatureHelp);

                // Retrigger
                Async.setTimeout(() -> editor.trigger('keyboard', Handler.Type, {text: triggerChar}), 0);
            }
            else {
                assertEquals(2, invokeCount);
                assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
                assertEquals(true, context.isRetrigger);
                assertEquals(triggerChar, context.triggerCharacter);
                assertTrue(context.activeSignatureHelp == emptySigHelp);

                done = true;
            }
            resolve(emptySigHelpResult);
        })));

        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', Handler.Type, {text: triggerChar});
            scheduler.runUntil(() -> done);
        });
        assertTrue(done);
    }

    function testProviderShouldNotBeRetriggeredIfPreviousHelpIsCanceledFirst() {
        var done = false;

        final triggerChar = '(';

        final editor = createMockEditor('');
        final hintModel = new ParameterHintsModel(editor, registry);
        disposables.add(hintModel);

        var invokeCount = 0;
        disposables.add(registry.register(mockFileSelector, new TestSignatureHelpProvider([triggerChar], [], (_model, _position, _token, context, resolve) -> {
            ++invokeCount;
            if (invokeCount == 1) {
                assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
                assertEquals(triggerChar, context.triggerCharacter);
                assertEquals(false, context.isRetrigger);
                assertEquals(null, context.activeSignatureHelp);

                // Cancel and retrigger
                hintModel.cancel();
                editor.trigger('keyboard', Handler.Type, {text: triggerChar});
            }
            else {
                assertEquals(2, invokeCount);
                assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
                assertEquals(triggerChar, context.triggerCharacter);
                assertEquals(true, context.isRetrigger);
                assertEquals(null, context.activeSignatureHelp);
                done = true;
            }
            resolve(emptySigHelpResult);
        })));

        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', Handler.Type, {text: triggerChar});
            scheduler.runUntil(() -> done);
        });
        assertTrue(done);
    }

    function testProviderShouldGetLastTriggerCharacterWhenTriggeredMultipleTimesAndOnlyBeInvokedOnce() {
        var done = false;

        final editor = createMockEditor('');
        disposables.add(new ParameterHintsModel(editor, registry, 5));

        var invokeCount = 0;
        disposables.add(registry.register(mockFileSelector, new TestSignatureHelpProvider(['a', 'b', 'c'], [], (_model, _position, _token, context, resolve) -> {
            ++invokeCount;

            assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
            assertEquals(false, context.isRetrigger);
            assertEquals('c', context.triggerCharacter);

            // Give some time to allow for later triggers
            Async.setTimeout(() -> {
                assertEquals(1, invokeCount);

                done = true;
            }, 50);
            resolve(null);
        })));

        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', Handler.Type, {text: 'a'});
            editor.trigger('keyboard', Handler.Type, {text: 'b'});
            editor.trigger('keyboard', Handler.Type, {text: 'c'});

            scheduler.runUntil(() -> done);
        });
        assertTrue(done);
    }

    function testProviderShouldBeRetriggeredIfAlreadyActive2() {
        var done = false;

        final editor = createMockEditor('');
        disposables.add(new ParameterHintsModel(editor, registry, 5));

        var invokeCount = 0;

        disposables.add(registry.register(mockFileSelector, new TestSignatureHelpProvider(['a', 'b'], [], (_model, _position, _token, context, resolve) -> {
            ++invokeCount;
            if (invokeCount == 1) {
                assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
                assertEquals('a', context.triggerCharacter);

                // retrigger after delay for widget to show up
                Async.setTimeout(() -> editor.trigger('keyboard', Handler.Type, {text: 'b'}), 50);
            }
            else if (invokeCount == 2) {
                assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
                assertTrue(context.isRetrigger);
                assertEquals('b', context.triggerCharacter);
                done = true;
            }
            else {
                fail('Unexpected invoke');
            }

            resolve(emptySigHelpResult);
        })));

        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', Handler.Type, {text: 'a'});
            scheduler.runUntil(() -> done);
        });
        assertTrue(done);
    }

    function testShouldCancelExistingRequestWhenNewRequestComesIn() {

        final editor = createMockEditor('abc def');
        final hintsModel = new ParameterHintsModel(editor, registry);
        disposables.add(hintsModel);

        var didRequestCancellationOf = -1;
        var invokeCount = 0;
        final longRunningProvider = new TestSignatureHelpProvider([], [], (_model, _position, token, _context, resolve) -> {
            final count = invokeCount++;
            disposables.add(token.onCancellationRequested(() -> {
                didRequestCancellationOf = count;
            }));

            // retrigger on first request
            if (count == 0) {
                hintsModel.trigger({triggerKind: SignatureHelpTriggerKind.Invoke}, 0);
            }

            Async.setTimeout(() -> {
                resolve({
                    value: {
                        signatures: [{
                            label: '' + count,
                            parameters: []
                        }],
                        activeParameter: 0,
                        activeSignature: 0
                    },
                    dispose: () -> {}
                });
            }, 100);
        });

        disposables.add(registry.register(mockFileSelector, longRunningProvider));

        var resolved = false;
        TimeTravelScheduler.runWithFakedTimers(scheduler -> {

            hintsModel.trigger({triggerKind: SignatureHelpTriggerKind.Invoke}, 0);
            assertEquals(-1, didRequestCancellationOf);

            disposables.add(hintsModel.onChangedHints(newParamterHints -> {
                if (resolved) {
                    return;
                }
                resolved = true;
                assertEquals(0, didRequestCancellationOf);
                assertEquals('1', newParamterHints.signatures[0].label);
            }));
            scheduler.runUntil(() -> resolved);
        });
        assertTrue(resolved);
    }

    function testProviderShouldBeRetriggeredByRetriggerCharacter() {
        var done = false;

        final triggerChar = 'a';
        final retriggerChar = 'b';

        final editor = createMockEditor('');
        disposables.add(new ParameterHintsModel(editor, registry, 5));

        var invokeCount = 0;
        disposables.add(registry.register(mockFileSelector, new TestSignatureHelpProvider([triggerChar], [retriggerChar], (_model, _position, _token, context, resolve) -> {
            ++invokeCount;
            if (invokeCount == 1) {
                assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
                assertEquals(triggerChar, context.triggerCharacter);

                // retrigger after delay for widget to show up
                Async.setTimeout(() -> editor.trigger('keyboard', Handler.Type, {text: retriggerChar}), 50);
            }
            else if (invokeCount == 2) {
                assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
                assertTrue(context.isRetrigger);
                assertEquals(retriggerChar, context.triggerCharacter);
                done = true;
            }
            else {
                fail('Unexpected invoke');
            }

            resolve(emptySigHelpResult);
        })));

        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            // This should not trigger anything
            editor.trigger('keyboard', Handler.Type, {text: retriggerChar});

            // But a trigger character should
            editor.trigger('keyboard', Handler.Type, {text: triggerChar});

            scheduler.runUntil(() -> done);
        });
        assertTrue(done);
    }

    function testShouldUseFirstResultFromMultipleProviders() {
        final triggerChar = 'a';
        final firstProviderId = 'firstProvider';
        final secondProviderId = 'secondProvider';
        final paramterLabel = 'parameter';

        final editor = createMockEditor('');
        final model = new ParameterHintsModel(editor, registry, 5);
        disposables.add(model);

        disposables.add(registry.register(mockFileSelector, new TestSignatureHelpProvider([triggerChar], [], (_model, _position, _token, context, resolve) -> {
            if (!context.isRetrigger) {
                // retrigger after delay for widget to show up
                Async.setTimeout(() -> editor.trigger('keyboard', Handler.Type, {text: triggerChar}), 50);

                resolve({
                    value: {
                        activeParameter: 0,
                        activeSignature: 0,
                        signatures: [{
                            label: firstProviderId,
                            parameters: [
                                {label: paramterLabel}
                            ]
                        }]
                    },
                    dispose: () -> {}
                });
                return;
            }

            resolve(null);
        })));

        disposables.add(registry.register(mockFileSelector, new TestSignatureHelpProvider([triggerChar], [], (_model, _position, _token, context, resolve) -> {
            if (context.isRetrigger) {
                resolve({
                    value: {
                        activeParameter: 0,
                        activeSignature: context.activeSignatureHelp != null ? context.activeSignatureHelp.activeSignature + 1 : 0,
                        signatures: [{
                            label: secondProviderId,
                            parameters: context.activeSignatureHelp != null ? context.activeSignatureHelp.signatures[0].parameters : []
                        }]
                    },
                    dispose: () -> {}
                });
                return;
            }

            resolve(null);
        })));

        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            final first = getNextHint(model);
            editor.trigger('keyboard', Handler.Type, {text: triggerChar});
            scheduler.runUntil(() -> first.fired);

            final firstHint = first.value;
            assertNotNull(firstHint);
            if (firstHint != null) {
                assertEquals(firstProviderId, firstHint.signatures[0].label);
                assertEquals(0, firstHint.activeSignature);
                assertEquals(paramterLabel, (cast firstHint.signatures[0].parameters[0].label : String));
            }

            final second = getNextHint(model);
            scheduler.runUntil(() -> second.fired);
            final secondHint = second.value;
            assertNotNull(secondHint);
            if (secondHint != null) {
                assertEquals(secondProviderId, secondHint.signatures[0].label);
                assertEquals(1, secondHint.activeSignature);
                assertEquals(paramterLabel, (cast secondHint.signatures[0].parameters[0].label : String));
            }
        });
    }

    function testQuickTypingShouldUseTheFirstTriggerCharacter() {
        final editor = createMockEditor('');
        final model = new ParameterHintsModel(editor, registry, 50);
        disposables.add(model);

        final triggerCharacter = 'a';

        var invokeCount = 0;
        disposables.add(registry.register(mockFileSelector, new TestSignatureHelpProvider([triggerCharacter], [], (_model, _position, _token, context, resolve) -> {
            ++invokeCount;

            if (invokeCount == 1) {
                assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
                assertEquals(triggerCharacter, context.triggerCharacter);
            }
            else {
                fail('Unexpected invoke');
            }

            resolve(emptySigHelpResult);
        })));

        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            final hint = getNextHint(model);
            editor.trigger('keyboard', Handler.Type, {text: triggerCharacter});
            editor.trigger('keyboard', Handler.Type, {text: 'x'});

            scheduler.runUntil(() -> hint.fired);
            assertTrue(hint.fired);
        });
    }

    function testRetriggerWhileAPendingResolveIsStillGoingOnShouldPreserveLastActiveSignature96702() {
        var done = false;

        final editor = createMockEditor('');
        final model = new ParameterHintsModel(editor, registry, 50);
        disposables.add(model);

        final triggerCharacter = 'a';
        final retriggerCharacter = 'b';

        var invokeCount = 0;
        disposables.add(registry.register(mockFileSelector, new TestSignatureHelpProvider([triggerCharacter], [retriggerCharacter], (_model, _position, _token, context, resolve) -> {
            ++invokeCount;

            if (invokeCount == 1) {
                assertEquals(SignatureHelpTriggerKind.TriggerCharacter, context.triggerKind);
                assertEquals(triggerCharacter, context.triggerCharacter);
                Async.setTimeout(() -> editor.trigger('keyboard', Handler.Type, {text: retriggerCharacter}), 50);
            }
            else if (invokeCount == 2) {
                // Trigger again while we wait for resolve to take place
                Async.setTimeout(() -> editor.trigger('keyboard', Handler.Type, {text: retriggerCharacter}), 50);
                // await new Promise(resolve => setTimeout(resolve, 1000))
                Async.setTimeout(() -> resolve(emptySigHelpResult), 1000);
                return;
            }
            else if (invokeCount == 3) {
                // Make sure that in a retrigger during a pending resolve, we still have the old active signature.
                assertTrue(context.activeSignatureHelp == emptySigHelp);
                done = true;
            }
            else {
                fail('Unexpected invoke');
            }

            resolve(emptySigHelpResult);
        })));

        TimeTravelScheduler.runWithFakedTimers(scheduler -> {

            final first = getNextHint(model);
            editor.trigger('keyboard', Handler.Type, {text: triggerCharacter});

            scheduler.runUntil(() -> first.fired);
            assertTrue(first.fired);
            final second = getNextHint(model);
            scheduler.runUntil(() -> second.fired);
            assertTrue(second.fired);

            scheduler.runUntil(() -> done);
        });
        assertTrue(done);
    }

}
