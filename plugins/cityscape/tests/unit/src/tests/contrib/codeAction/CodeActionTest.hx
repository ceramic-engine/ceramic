// Ported from vscode src/vs/editor/contrib/codeAction/test/browser/codeAction.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.codeAction;

import cityscape.base.common.Cancellation;
import cityscape.base.common.HierarchicalKind;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.contrib.codeAction.common.CodeActionTypes;
import cityscape.contrib.codeAction.view.CodeAction;
import cityscape.platform.markers.common.Markers;
import testing.TestCase;

/**
 * A code action provider of the tests (the classes and object literals of
 * the vscode tests).
 */
class TestCodeActionProvider implements CodeActionProvider {
    public var displayName(default, null):Null<String> = null;
    public var resolveCodeAction(default, null):Null<(codeAction:CodeAction, token:CancellationToken, resolve:(codeAction:Null<CodeAction>) -> Void) -> Void> = null;
    public var providedCodeActionKinds(default, null):Null<Array<String>>;
    public var documentation(default, null):Null<Array<CodeActionProviderDocumentation>> = null;

    final provide:(context:CodeActionContext) -> Null<CodeActionList>;

    public function new(provide:(context:CodeActionContext) -> Null<CodeActionList>, ?providedCodeActionKinds:Array<String>) {
        this.provide = provide;
        this.providedCodeActionKinds = providedCodeActionKinds;
    }

    public function provideCodeActions(model:ITextModel, range:Range, context:CodeActionContext, token:CancellationToken, resolve:(list:Null<CodeActionList>) -> Void):Void {
        resolve(provide(context));
    }

    /**
     * vscode's `staticCodeActionProvider`.
     */
    public static function staticCodeActionProvider(actions:Array<CodeAction>):TestCodeActionProvider {
        return new TestCodeActionProvider(_ -> {actions: actions, dispose: () -> {}});
    }
}

/**
 * suite('CodeAction'). The `async` tests run synchronously (the providers
 * answer at once).
 */
class CodeActionTest extends TestCase {

    static inline final langId = 'fooLang';
    var uri:Uri;
    var model:TextModel;
    var registry:LanguageFeatureRegistry<CodeActionProvider>;
    final disposables = new DisposableStore();

    static function diagnosticsAbc():CodeAction {
        return {
            title: 'bTitle',
            diagnostics: [{
                startLineNumber: 1,
                startColumn: 1,
                endLineNumber: 2,
                endColumn: 1,
                severity: MarkerSeverity.Error,
                message: 'abc'
            }]
        };
    }

    static function diagnosticsBcd():CodeAction {
        return {
            title: 'aTitle',
            diagnostics: [{
                startLineNumber: 1,
                startColumn: 1,
                endLineNumber: 2,
                endColumn: 1,
                severity: MarkerSeverity.Error,
                message: 'bcd'
            }]
        };
    }

    override public function setup():Void {
        uri = Uri.parse('untitled:path');
        registry = new LanguageFeatureRegistry();
        disposables.clear();
        model = tests.TestTextModel.createTextModel('test1\ntest2\ntest3', langId, null, uri);
        disposables.add(model);
    }

    override public function teardown():Void {
        disposables.clear();
    }

    function getCodeActions(trigger:CodeActionTrigger):CodeActionSet {
        var result:Null<CodeActionSet> = null;
        CodeActionUtils.getCodeActions(registry, model, new Range(1, 1, 2, 1), trigger, null, CancellationTokens.None).done(set -> result = set);
        assertNotNull(result, 'resolved synchronously');
        disposables.add(result);
        return result;
    }

    function testCodeActionsAreSortedByType38623() {

        final commandAbc:CodeAction = {command: {id: '1', title: 'abc'}, title: 'Extract to inner function in function "test"'};
        final spellingBcd:CodeAction = {diagnostics: [], edit: {edits: []}, title: 'abc'};
        final tsLintAbc:CodeAction = {title: 'abc'};
        final tsLintBcd:CodeAction = {title: 'bcd'};
        final dAbc = diagnosticsAbc();
        final dBcd = diagnosticsBcd();

        final provider = TestCodeActionProvider.staticCodeActionProvider([
            commandAbc,
            dBcd,
            spellingBcd,
            tsLintBcd,
            tsLintAbc,
            dAbc
        ]);

        disposables.add(registry.register('fooLang', provider));

        final expected = [
            // CodeActions with a diagnostics array are shown first without further sorting
            dBcd,
            dAbc,

            // CodeActions without diagnostics are shown in the given order without any further sorting
            commandAbc,
            spellingBcd,
            tsLintBcd,
            tsLintAbc
        ];

        final actions = getCodeActions({type: CodeActionTriggerType.Invoke, triggerAction: CodeActionTriggerSource.Default}).validActions;
        assertEquals(6, actions.length);
        for (i in 0...expected.length) {
            assertTrue(actions[i].action == expected[i], 'action ' + i);
            assertTrue(actions[i].provider == provider);
        }
    }

    function testGetCodeActionsShouldFilterByScope() {
        final provider = TestCodeActionProvider.staticCodeActionProvider([
            {title: 'a', kind: 'a'},
            {title: 'b', kind: 'b'},
            {title: 'a.b', kind: 'a.b'}
        ]);

        disposables.add(registry.register('fooLang', provider));

        {
            final actions = getCodeActions({type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.Default, filter: {include: new HierarchicalKind('a')}}).validActions;
            assertEquals(2, actions.length);
            assertEquals('a', actions[0].action.title);
            assertEquals('a.b', actions[1].action.title);
        }

        {
            final actions = getCodeActions({type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.Default, filter: {include: new HierarchicalKind('a.b')}}).validActions;
            assertEquals(1, actions.length);
            assertEquals('a.b', actions[0].action.title);
        }

        {
            final actions = getCodeActions({type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.Default, filter: {include: new HierarchicalKind('a.b.c')}}).validActions;
            assertEquals(0, actions.length);
        }
    }

    function testGetCodeActionsShouldForwardRequestedScopeToProviders() {
        final provider = new TestCodeActionProvider(context -> {
            return {
                actions: [
                    {title: context.only != null ? context.only : '', kind: context.only}
                ],
                dispose: () -> {}
            };
        });

        disposables.add(registry.register('fooLang', provider));

        final actions = getCodeActions({type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.Default, filter: {include: new HierarchicalKind('a')}}).validActions;
        assertEquals(1, actions.length);
        assertEquals('a', actions[0].action.title);
    }

    function testGetCodeActionsShouldNotReturnSourceCodeActionByDefault() {
        final provider = TestCodeActionProvider.staticCodeActionProvider([
            {title: 'a', kind: CodeActionKind.Source.value},
            {title: 'b', kind: 'b'}
        ]);

        disposables.add(registry.register('fooLang', provider));

        {
            final actions = getCodeActions({type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.SourceAction}).validActions;
            assertEquals(1, actions.length);
            assertEquals('b', actions[0].action.title);
        }

        {
            final actions = getCodeActions({type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.Default, filter: {include: CodeActionKind.Source, includeSourceActions: true}}).validActions;
            assertEquals(1, actions.length);
            assertEquals('a', actions[0].action.title);
        }
    }

    function testGetCodeActionsShouldSupportFilteringOutSomeRequestedSourceCodeActions84602() {
        final provider = TestCodeActionProvider.staticCodeActionProvider([
            {title: 'a', kind: CodeActionKind.Source.value},
            {title: 'b', kind: CodeActionKind.Source.append('test').value},
            {title: 'c', kind: 'c'}
        ]);

        disposables.add(registry.register('fooLang', provider));

        {
            final actions = getCodeActions({
                type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.SourceAction, filter: {
                    include: CodeActionKind.Source.append('test'),
                    excludes: [CodeActionKind.Source],
                    includeSourceActions: true,
                }
            }).validActions;
            assertEquals(1, actions.length);
            assertEquals('b', actions[0].action.title);
        }
    }

    function testGetCodeActionsNoInvokeAProviderThatHasBeenExcluded84602() {
        final baseType = CodeActionKind.Refactor;
        final subType = CodeActionKind.Refactor.append('sub');

        disposables.add(registry.register('fooLang', TestCodeActionProvider.staticCodeActionProvider([
            {title: 'a', kind: baseType.value}
        ])));

        var didInvoke = false;
        disposables.add(registry.register('fooLang', new TestCodeActionProvider(_ -> {
            didInvoke = true;
            return {
                actions: [
                    {title: 'x', kind: subType.value}
                ],
                dispose: () -> {}
            };
        }, [subType.value])));

        {
            final actions = getCodeActions({
                type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.Refactor, filter: {
                    include: baseType,
                    excludes: [subType],
                }
            }).validActions;
            assertEquals(false, didInvoke);
            assertEquals(1, actions.length);
            assertEquals('a', actions[0].action.title);
        }
    }

    function testGetCodeActionsShouldNotInvokeCodeActionProvidersFilteredOutByProvidedCodeActionKinds() {
        var wasInvoked = false;
        final provider = new TestCodeActionProvider(_ -> {
            wasInvoked = true;
            return {actions: [], dispose: () -> {}};
        }, [CodeActionKind.Refactor.value]);

        disposables.add(registry.register('fooLang', provider));

        final actions = getCodeActions({
            type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.Refactor,
            filter: {
                include: CodeActionKind.QuickFix
            }
        }).validActions;
        assertEquals(0, actions.length);
        assertEquals(false, wasInvoked);
    }

}
