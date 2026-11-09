// Ported from vscode src/vs/editor/contrib/stickyScroll/test/browser/stickyScroll.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.stickyScroll;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Selection;
import cityscape.contrib.folding.view.Folding;
import cityscape.contrib.stickyScroll.view.StickyScrollController;
import cityscape.contrib.stickyScroll.view.StickyScrollElement.StickyRange;
import cityscape.contrib.stickyScroll.view.StickyScrollProvider;
import cityscape.view.EditorExtensions.EditorContributionInstantiation;
import testing.TestCase;
import testing.TestCodeEditor;
import tests.TestTextModel;

private class TestDocumentSymbolProvider implements DocumentSymbolProvider {

    public var displayName(default, null):Null<String> = null;

    final symbols:Array<DocumentSymbol>;

    public function new(symbols:Array<DocumentSymbol>) {
        this.symbols = symbols;
    }

    public function provideDocumentSymbols(model:ITextModel, token:CancellationToken, resolve:(symbols:Null<Array<DocumentSymbol>>) -> Void):Void {
        resolve(symbols);
    }

}

/**
 * suite('Sticky Scroll Tests'), plus Cityscape tests of the models without
 * a document symbol provider (folding providers and indentation), the
 * widget state and a click on a sticky line.
 *
 * vscode runs these tests with faked timers and awaits the promises; the
 * updates are flushed here (`_flushPendingUpdate`). `withAsyncTestCodeEditor`
 * with `envConfig: {outerHeight: 500}` is a test editor 500 pixels high.
 */
class StickyScrollTest extends TestCase {

    static final text = [
        'function foo() {',
        '',
        '}',
        '/* comment related to TestClass',
        ' end of the comment */',
        '@classDecorator',
        'class TestClass {',
        '// comment related to the function functionOfClass',
        'functionOfClass(){',
        'function function1(){',
        '}',
        '}}',
        'function bar() { function insideBar() {}',
        '}'
    ].join('\n');

    static function documentSymbolProviderForTestModel():DocumentSymbolProvider {
        return new TestDocumentSymbolProvider([
            {
                name: 'foo',
                detail: 'foo',
                kind: cityscape.common.SymbolKind.Function,
                tags: [],
                range: {startLineNumber: 1, endLineNumber: 3, startColumn: 1, endColumn: 1},
                selectionRange: {startLineNumber: 1, endLineNumber: 1, startColumn: 1, endColumn: 1}
            },
            {
                name: 'TestClass',
                detail: 'TestClass',
                kind: cityscape.common.SymbolKind.Class,
                tags: [],
                range: {startLineNumber: 4, endLineNumber: 12, startColumn: 1, endColumn: 1},
                selectionRange: {startLineNumber: 7, endLineNumber: 7, startColumn: 1, endColumn: 1},
                children: [
                    {
                        name: 'functionOfClass',
                        detail: 'functionOfClass',
                        kind: cityscape.common.SymbolKind.Function,
                        tags: [],
                        range: {startLineNumber: 8, endLineNumber: 12, startColumn: 1, endColumn: 1},
                        selectionRange: {startLineNumber: 9, endLineNumber: 9, startColumn: 1, endColumn: 1},
                        children: [
                            {
                                name: 'function1',
                                detail: 'function1',
                                kind: cityscape.common.SymbolKind.Function,
                                tags: [],
                                range: {startLineNumber: 10, endLineNumber: 11, startColumn: 1, endColumn: 1},
                                selectionRange: {startLineNumber: 10, endLineNumber: 10, startColumn: 1, endColumn: 1},
                            }
                        ]
                    }
                ]
            },
            {
                name: 'bar',
                detail: 'bar',
                kind: cityscape.common.SymbolKind.Function,
                tags: [],
                range: {startLineNumber: 13, endLineNumber: 14, startColumn: 1, endColumn: 1},
                selectionRange: {startLineNumber: 13, endLineNumber: 13, startColumn: 1, endColumn: 1},
                children: [
                    {
                        name: 'insideBar',
                        detail: 'insideBar',
                        kind: cityscape.common.SymbolKind.Function,
                        tags: [],
                        range: {startLineNumber: 13, endLineNumber: 13, startColumn: 1, endColumn: 1},
                        selectionRange: {startLineNumber: 13, endLineNumber: 13, startColumn: 1, endColumn: 1},
                    }
                ]
            }
        ]);
    }

    static final textWithScopesWithSameStartingLines = [
        'class TestClass { foo() {',
        'function bar(){',
        '',
        '}}',
        '}',
        ''
    ].join('\n');

    static function documentSymbolProviderForSecondTestModel():DocumentSymbolProvider {
        return new TestDocumentSymbolProvider([
            {
                name: 'TestClass',
                detail: 'TestClass',
                kind: cityscape.common.SymbolKind.Class,
                tags: [],
                range: {startLineNumber: 1, endLineNumber: 5, startColumn: 1, endColumn: 1},
                selectionRange: {startLineNumber: 1, endLineNumber: 1, startColumn: 1, endColumn: 1},
                children: [
                    {
                        name: 'foo',
                        detail: 'foo',
                        kind: cityscape.common.SymbolKind.Function,
                        tags: [],
                        range: {startLineNumber: 1, endLineNumber: 4, startColumn: 1, endColumn: 1},
                        selectionRange: {startLineNumber: 1, endLineNumber: 1, startColumn: 1, endColumn: 1},
                        children: [
                            {
                                name: 'bar',
                                detail: 'bar',
                                kind: cityscape.common.SymbolKind.Function,
                                tags: [],
                                range: {startLineNumber: 2, endLineNumber: 4, startColumn: 1, endColumn: 1},
                                selectionRange: {startLineNumber: 2, endLineNumber: 2, startColumn: 1, endColumn: 1},
                                children: []
                            }
                        ]
                    },
                ]
            }
        ]);
    }

    static final STICKY_OPTIONS:IEditorOptions = {
        stickyScroll: {
            enabled: true,
            maxLineCount: 5,
            defaultModel: 'outlineModel'
        }
    };

    /**
     * `withAsyncTestCodeEditor(model, {stickyScroll, envConfig: {outerHeight: 500}})`.
     */
    static function withEditor(content:String, options:IEditorOptions, callback:(editor:TestCodeEditor, context:Cityscape) -> Void, ?contributions:Array<String>):Void {
        final context = new Cityscape();
        final model = TestTextModel.instantiateTextModel(context, content);
        final editor = new TestCodeEditor(context, model, options, contributions != null ? context.editorExtensions.getSomeEditorContributions(contributions) : [], {outerHeight: 500});
        editor.getViewModel().setHasFocus(true);
        try {
            callback(editor, context);
        }
        catch (e:Dynamic) {
            editor.dispose();
            model.dispose();
            throw e;
        }
        editor.dispose();
        model.dispose();
    }

    static function candidates(list:Array<StickyLineCandidate>):String {
        return [for (c in list) c.toString()].join(', ');
    }

    static function stateOf(controller:StickyScrollController):String {
        return haxe.Json.stringify(controller.findScrollWidgetState().startLineNumbers);
    }

    function testTestingTheFunctionGetCandidateStickyLinesIntersecting() {
        withEditor(text, STICKY_OPTIONS, (editor, context) -> {
            final languageService = context.languageFeaturesService;
            final languageConfigurationService = context.languageConfigurationService;
            final registration = languageService.documentSymbolProvider.register('*', documentSymbolProviderForTestModel());
            final provider = new StickyLineCandidateProvider(editor, languageService, languageConfigurationService);
            provider.update();
            provider._flushPendingUpdate();
            assertEquals(candidates([new StickyLineCandidate(1, 2, 1)]), candidates(provider.getCandidateStickyLinesIntersecting(new StickyRange(1, 4))));
            assertEquals(candidates([new StickyLineCandidate(7, 11, 1), new StickyLineCandidate(9, 11, 2), new StickyLineCandidate(10, 10, 3)]), candidates(provider.getCandidateStickyLinesIntersecting(new StickyRange(8, 10))));
            assertEquals(candidates([new StickyLineCandidate(7, 11, 1), new StickyLineCandidate(9, 11, 2), new StickyLineCandidate(10, 10, 3)]), candidates(provider.getCandidateStickyLinesIntersecting(new StickyRange(10, 13))));

            provider.dispose();
            registration.dispose();
        });
    }

    function stickyController(editor:TestCodeEditor):StickyScrollController {
        return editor.registerAndInstantiateContribution(StickyScrollController.ID, e -> new StickyScrollController(e));
    }

    static function update(controller:StickyScrollController):Void {
        final provider:StickyLineCandidateProvider = cast controller.stickyScrollCandidateProvider;
        provider.update();
        provider._flushPendingUpdate();
    }

    function testIssue157180RenderTheCorrectLineCorrespondingToTheScopeDefinition() {
        withEditor(text, STICKY_OPTIONS, (editor, context) -> {
            final stickyScrollController = stickyController(editor);
            final lineHeight:Float = editor.getOption(EditorOption.lineHeight);
            final registration = context.languageFeaturesService.documentSymbolProvider.register('*', documentSymbolProviderForTestModel());
            update(stickyScrollController);

            editor.setScrollTop(1);
            assertEquals('[1]', stateOf(stickyScrollController));

            editor.setScrollTop(lineHeight + 1);
            assertEquals('[1]', stateOf(stickyScrollController));

            editor.setScrollTop(4 * lineHeight + 1);
            assertEquals('[]', stateOf(stickyScrollController));

            editor.setScrollTop(8 * lineHeight + 1);
            assertEquals('[7,9]', stateOf(stickyScrollController));

            editor.setScrollTop(9 * lineHeight + 1);
            assertEquals('[7,9]', stateOf(stickyScrollController));

            editor.setScrollTop(10 * lineHeight + 1);
            assertEquals('[7]', stateOf(stickyScrollController));

            registration.dispose();
        });
    }

    function testIssue156268DoNotRevealStickyLinesWhenTheyAreInAFoldedRegion() {
        withEditor(text, STICKY_OPTIONS, (editor, context) -> {
            final stickyScrollController = stickyController(editor);
            final lineHeight:Float = editor.getOption(EditorOption.lineHeight);

            final registration = context.languageFeaturesService.documentSymbolProvider.register('*', documentSymbolProviderForTestModel());
            update(stickyScrollController);
            editor.setHiddenAreas([{startLineNumber: 2, endLineNumber: 2, startColumn: 1, endColumn: 1}, {startLineNumber: 10, endLineNumber: 11, startColumn: 1, endColumn: 1}]);

            editor.setScrollTop(1);
            assertEquals('[1]', stateOf(stickyScrollController));

            editor.setScrollTop(lineHeight + 1);
            assertEquals('[]', stateOf(stickyScrollController));

            editor.setScrollTop(6 * lineHeight + 1);
            assertEquals('[7,9]', stateOf(stickyScrollController));

            editor.setScrollTop(7 * lineHeight + 1);
            assertEquals('[7]', stateOf(stickyScrollController));

            editor.setScrollTop(10 * lineHeight + 1);
            assertEquals('[]', stateOf(stickyScrollController));

            registration.dispose();
        });
    }

    function testIssue159271RenderTheCorrectWidgetStateWhenTheChildScopeStartsOnTheSameLineAsTheParentScope() {
        withEditor(textWithScopesWithSameStartingLines, STICKY_OPTIONS, (editor, context) -> {
            final stickyScrollController = stickyController(editor);
            update(stickyScrollController);
            final lineHeight:Float = editor.getOption(EditorOption.lineHeight);

            final registration = context.languageFeaturesService.documentSymbolProvider.register('*', documentSymbolProviderForSecondTestModel());
            update(stickyScrollController);

            editor.setScrollTop(1);
            assertEquals('[1,2]', stateOf(stickyScrollController));

            editor.setScrollTop(lineHeight + 1);
            assertEquals('[1,2]', stateOf(stickyScrollController));

            editor.setScrollTop(2 * lineHeight + 1);
            assertEquals('[1]', stateOf(stickyScrollController));

            editor.setScrollTop(3 * lineHeight + 1);
            assertEquals('[1]', stateOf(stickyScrollController));

            editor.setScrollTop(4 * lineHeight + 1);
            assertEquals('[]', stateOf(stickyScrollController));

            registration.dispose();
        });
    }

    // ---- Cityscape tests (expected values from Monaco's code: the indentation model, the widget)

    static final INDENTED = [
        'class A {',
        '    function b() {',
        '        if (c) {',
        '            d();',
        '            e();',
        '            f();',
        '        }',
        '        g();',
        '    }',
        '    function h() {',
        '        i();',
        '    }',
        '}'
    ].join('\n');

    function testCityscapeIndentationModelWithoutProviders() {
        // `outlineModel` (the default) falls back to the folding providers, then to the indentation
        withEditor(INDENTED, {}, (editor, context) -> {
            final stickyScrollController = stickyController(editor);
            update(stickyScrollController);
            final lineHeight:Float = editor.getOption(EditorOption.lineHeight);

            editor.setScrollTop(0);
            assertEquals('[]', stateOf(stickyScrollController));

            // line 4 at the top: `class A`, `function b`, `if (c)` stick
            editor.setScrollTop(3 * lineHeight);
            assertEquals('[1,2,3]', stateOf(stickyScrollController));

            // line 8 at the top: the `if` block ended
            editor.setScrollTop(7 * lineHeight);
            assertEquals('[1,2]', stateOf(stickyScrollController));

            // line 11 at the top: the second function
            editor.setScrollTop(10 * lineHeight);
            assertEquals('[1,10]', stateOf(stickyScrollController));
        });
    }

    function testCityscapeIndentationModelOption() {
        withEditor(INDENTED, {stickyScroll: {defaultModel: 'indentationModel', maxLineCount: 2}}, (editor, context) -> {
            final stickyScrollController = stickyController(editor);
            update(stickyScrollController);
            final lineHeight:Float = editor.getOption(EditorOption.lineHeight);
            // at most 2 lines
            editor.setScrollTop(3 * lineHeight);
            assertEquals('[1,2]', stateOf(stickyScrollController));
        });
    }

    function testCityscapeDisabled() {
        withEditor(INDENTED, {stickyScroll: {enabled: false}}, (editor, context) -> {
            final stickyScrollController = stickyController(editor);
            update(stickyScrollController);
            final lineHeight:Float = editor.getOption(EditorOption.lineHeight);
            editor.setScrollTop(3 * lineHeight);
            // the provider has no model when sticky scroll is disabled
            assertEquals('[]', stateOf(stickyScrollController));
        });
    }

    function testCityscapeWidgetStateAndClick() {
        withEditor(INDENTED, {}, (editor, context) -> {
            final stickyScrollController = stickyController(editor);
            update(stickyScrollController);
            final lineHeight:Float = editor.getOption(EditorOption.lineHeight);

            // the scroll event renders the widget
            editor.setScrollTop(3 * lineHeight);
            final widget = stickyScrollController.stickyScrollWidget;
            assertEquals('[1,2,3]', haxe.Json.stringify(widget.lineNumbers));
            assertEquals(3 * lineHeight, widget.height);
            assertEquals(true, editor.contextKeyService.getContextKeyValue('stickyScrollVisible'));

            // a click on the second sticky line reveals `function b`
            final contentLeft = editor.getLayoutInfo().contentLeft;
            stickyScrollController.clickAt(contentLeft + 1, lineHeight + 1);
            assertEquals('[2,1 -> 2,1]', editor.getSelection().toString());

            // a click in the line numbers does nothing
            editor.setScrollTop(3 * lineHeight);
            editor.setSelection(new Selection(5, 1, 5, 1));
            stickyScrollController.clickAt(1, 1);
            assertEquals('[5,1 -> 5,1]', editor.getSelection().toString());
        });
    }

    function testCityscapeLastLinePushedUp() {
        withEditor(INDENTED, {}, (editor, context) -> {
            final stickyScrollController = stickyController(editor);
            update(stickyScrollController);
            final lineHeight:Float = editor.getOption(EditorOption.lineHeight);
            // the `if` block ends on line 7: 10 pixels after a scroll of 3
            // lines, the third sticky line is pushed up by 10 pixels (the
            // scroll position is an integer, like Monaco's)
            editor.setScrollTop(3 * lineHeight + 10);
            final state = stickyScrollController.findScrollWidgetState();
            assertEquals('[1,2,3]', haxe.Json.stringify(state.startLineNumbers));
            assertEquals(-10.0, state.lastLineRelativePosition);
        });
    }

    function testCityscapeActionsAndKeybindings() {
        final context = new Cityscape();
        final registry = context.editorExtensions;
        final ids = [for (rule in context.keybindingsRegistry.getDefaultKeybindings()) rule.command];
        assertTrue(ids.indexOf('editor.action.selectNextStickyScrollLine') != -1);
        assertTrue(ids.indexOf('editor.action.selectPreviousStickyScrollLine') != -1);
        assertTrue(ids.indexOf('editor.action.goToFocusedStickyScrollLine') != -1);
        assertTrue(ids.indexOf('editor.action.selectEditor') != -1);
        assertTrue(context.commandsRegistry.getCommand('editor.action.toggleStickyScroll') != null);
        assertTrue(context.commandsRegistry.getCommand('editor.action.focusStickyScroll') != null);
        assertEquals(1, [for (c in registry.getEditorContributions()) if (c.id == StickyScrollController.ID) c].length);
    }

    function testCityscapeKeyboardFocus() {
        withEditor(INDENTED, {}, (editor, context) -> {
            final stickyScrollController = stickyController(editor);
            update(stickyScrollController);
            final lineHeight:Float = editor.getOption(EditorOption.lineHeight);
            editor.setScrollTop(3 * lineHeight);
            stickyScrollController.focus();
            assertEquals(true, editor.contextKeyService.getContextKeyValue('stickyScrollFocused'));
            assertEquals(2, stickyScrollController.stickyScrollWidget.focusedLineIndex);
            stickyScrollController.focusPrevious();
            assertEquals(1, stickyScrollController.stickyScrollWidget.focusedLineIndex);
            stickyScrollController.goToFocused();
            assertEquals(false, editor.contextKeyService.getContextKeyValue('stickyScrollFocused'));
            assertEquals('[2,1 -> 2,1]', editor.getSelection().toString());
        });
    }

}
