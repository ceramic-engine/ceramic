// Ported from vscode src/vs/editor/contrib/indentation/test/browser/indentation.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.indentation;

// Classes of this module (one per suite of vscode):
// - IndentationTestUtils (module functions of the test file)
// - ChangeIndentationToSpacesTest
// - ChangeIndentationToTabsTest
// - IndentWithTabTest
// - AutoIndentOnPasteTypeScriptTest
// - AutoIndentOnTypeTypeScriptTest
// - AutoIndentOnTypeRubyTest
// - AutoIndentOnTypePHPTest
// - AutoIndentOnPasteGoTest
// - AutoIndentOnTypeCPPTest
// - AutoIndentOnTypeHTMLTest
// - AutoIndentOnTypeVisualBasicTest
// - AutoIndentOnTypeLatexTest
// - AutoIndentOnTypeLuaTest

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.languages.NullTokenize;
import cityscape.common.model.TextModel;
import cityscape.common.services.LanguageService;
import cityscape.common.viewModel.ViewModelImpl;
import cityscape.contrib.indentation.view.Indentation;
import haxe.io.UInt32Array;
import testing.TestCase;
import testing.TestCodeEditor;
import testing.TestCommand;
import testing.TestTokenizationSupport;
import tests.TestTextModel;
import tests.modes.supports.AutoClosingPairsRules.*;
import tests.modes.supports.BracketRules.*;
import tests.modes.supports.IndentationRules.*;
import tests.modes.supports.OnEnterRules.*;

/**
 * The languages of the tests (vscode's `Language` enum).
 */
enum abstract Language(String) to String {
    var TypeScript = 'ts-test';
    var Ruby = 'ruby-test';
    var PHP = 'php-test';
    var Go = 'go-test';
    var CPP = 'cpp-test';
    var HTML = 'html-test';
    var VB = 'vb-test';
    var Latex = 'latex-test';
    var Lua = 'lua-test';
}

typedef StandardTokenTypeData = {
    var startIndex:Int;
    var standardTokenType:StandardTokenType;
}

/**
 * The module functions of indentation.test.ts (also used by
 * indentationLineProcessor.test.ts). The services of vscode's
 * `serviceCollection` (language service, language configuration service,
 * tokenization registry) are those of a `Cityscape` context.
 */
class IndentationTestUtils {

    public static function testIndentationToSpacesCommand(test:TestCase, lines:Array<String>, selection:Selection, tabSize:Int, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
        TestCommand.testCommand(test, lines, null, selection, (accessor, sel) -> new IndentationToSpacesCommand(sel, tabSize), expectedLines, expectedSelection, null, null, pos);
    }

    public static function testIndentationToTabsCommand(test:TestCase, lines:Array<String>, selection:Selection, tabSize:Int, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
        TestCommand.testCommand(test, lines, null, selection, (accessor, sel) -> new IndentationToTabsCommand(sel, tabSize), expectedLines, expectedSelection, null, null, pos);
    }

    public static function registerLanguage(languageService:LanguageService, language:Language):IDisposable {
        return languageService.registerLanguage({id: language});
    }

    public static function registerLanguageConfiguration(languageConfigurationService:ILanguageConfigurationService, language:Language):IDisposable {
        switch (language) {
            case Language.TypeScript:
                return languageConfigurationService.register(language, {
                    brackets: typescriptBracketRules,
                    comments: {
                        lineComment: '//',
                        blockComment: ['/*', '*/']
                    },
                    autoClosingPairs: javascriptAutoClosingPairsRules,
                    indentationRules: javascriptIndentationRules,
                    onEnterRules: javascriptOnEnterRules
                });
            case Language.Ruby:
                return languageConfigurationService.register(language, {
                    brackets: rubyBracketRules,
                    indentationRules: rubyIndentationRules,
                });
            case Language.PHP:
                return languageConfigurationService.register(language, {
                    brackets: phpBracketRules,
                    indentationRules: phpIndentationRules,
                    onEnterRules: phpOnEnterRules
                });
            case Language.Go:
                return languageConfigurationService.register(language, {
                    brackets: goBracketRules,
                    indentationRules: goIndentationRules
                });
            case Language.CPP:
                return languageConfigurationService.register(language, {
                    brackets: cppBracketRules,
                    onEnterRules: cppOnEnterRules
                });
            case Language.HTML:
                return languageConfigurationService.register(language, {
                    brackets: htmlBracketRules,
                    indentationRules: htmlIndentationRules,
                    onEnterRules: htmlOnEnterRules
                });
            case Language.VB:
                return languageConfigurationService.register(language, {
                    brackets: vbBracketRules,
                });
            case Language.Latex:
                return languageConfigurationService.register(language, {
                    brackets: latexBracketRules,
                    autoClosingPairs: [for (pair in latexAutoClosingPairsRules) {open: pair.open, close: pair.close}],
                    indentationRules: latexIndentationRules
                });
            case Language.Lua:
                return languageConfigurationService.register(language, {
                    brackets: luaBracketRules,
                    indentationRules: luaIndentationRules
                });
        }
    }

    /**
     * Registers a tokenizer giving the tokens of `tokens`, one line per
     * call (vscode's `lineIndex++`).
     */
    public static function registerTokenizationSupport(instantiationService:Cityscape, tokens:Array<Array<StandardTokenTypeData>>, languageId:Language):IDisposable {
        var lineIndex = 0;
        final languageService = instantiationService.languageService;
        final tokenizationSupport:ITokenizationSupport = new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line:String, hasEOL:Bool, state:IState) -> {
                final tokensOnLine = tokens[lineIndex++];
                if (tokensOnLine == null) {
                    // vscode reads `undefined.length` and throws
                    throw 'Cannot read properties of undefined (reading \'length\')';
                }
                final encodedLanguageId:Int = languageService.languageIdCodec.encodeLanguageId(languageId);
                final result = new UInt32Array(2 * tokensOnLine.length);
                for (i in 0...tokensOnLine.length) {
                    result[2 * i] = tokensOnLine[i].startIndex;
                    result[2 * i + 1] =
                        (
                            (encodedLanguageId << MetadataConsts.LANGUAGEID_OFFSET)
                            | ((tokensOnLine[i].standardTokenType : Int) << MetadataConsts.TOKEN_TYPE_OFFSET)
                        );
                }
                return new EncodedTokenizationResult(result, state);
            }
        );
        return instantiationService.tokenizationRegistry.register(languageId, tokenizationSupport);
    }

}

/**
 * The setup of the suites that register a language: a context (vscode's
 * `serviceCollection`) with the language and its configuration.
 */
class IndentationLanguageSuite extends TestCase {

    final languageId:Language;
    var disposables:DisposableStore;
    var instantiationService:Cityscape;

    public function new(languageId:Language) {
        super();
        this.languageId = languageId;
    }

    override function setup():Void {
        disposables = new DisposableStore();
        instantiationService = new Cityscape();
        disposables.add(IndentationTestUtils.registerLanguage(instantiationService.languageService, languageId));
        disposables.add(IndentationTestUtils.registerLanguageConfiguration(instantiationService.languageConfigurationService, languageId));
    }

    override function teardown():Void {
        disposables.dispose();
    }

    function createTextModel(lines:String):TextModel {
        return TestTextModel.instantiateTextModel(instantiationService, lines, languageId);
    }

    function withTestCodeEditor(model:TextModel, autoIndent:String, callback:(editor:TestCodeEditor, viewModel:ViewModel, instantiationService:Cityscape) -> Void):Void {
        final services = instantiationService;
        TestCodeEditor.withTestCodeEditor(model, {autoIndent: autoIndent}, (editor, viewModel) -> callback(editor, viewModel, services), instantiationService);
    }

    function registerTokenizationSupport(instantiationService:Cityscape, tokens:Array<Array<StandardTokenTypeData>>, languageId:Language):IDisposable {
        return IndentationTestUtils.registerTokenizationSupport(instantiationService, tokens, languageId);
    }

}

/**
 * suite('Change Indentation to Spaces - TypeScript/Javascript')
 */
class ChangeIndentationToSpacesTest extends TestCase {

    function testSingleTabsOnlyAtStartOfLine() {
        IndentationTestUtils.testIndentationToSpacesCommand(this,
            [
                'first',
                'second line',
                'third line',
                '\tfourth line',
                '\tfifth'
            ],
            new Selection(2, 3, 2, 3),
            4,
            [
                'first',
                'second line',
                'third line',
                '    fourth line',
                '    fifth'
            ],
            new Selection(2, 3, 2, 3)
        );
    }

    function testMultipleTabsAtStartOfLine() {
        IndentationTestUtils.testIndentationToSpacesCommand(this,
            [
                '\t\tfirst',
                '\tsecond line',
                '\t\t\t third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 5, 1, 5),
            3,
            [
                '      first',
                '   second line',
                '          third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 9, 1, 9)
        );
    }

    function testMultipleTabs() {
        IndentationTestUtils.testIndentationToSpacesCommand(this,
            [
                '\t\tfirst\t',
                '\tsecond  \t line \t',
                '\t\t\t third line',
                ' \tfourth line',
                'fifth'
            ],
            new Selection(1, 5, 1, 5),
            2,
            [
                '    first\t',
                '  second  \t line \t',
                '       third line',
                '   fourth line',
                'fifth'
            ],
            new Selection(1, 7, 1, 7)
        );
    }

    function testEmptyLines() {
        IndentationTestUtils.testIndentationToSpacesCommand(this,
            [
                '\t\t\t',
                '\t',
                '\t\t'
            ],
            new Selection(1, 4, 1, 4),
            2,
            [
                '      ',
                '  ',
                '    '
            ],
            new Selection(1, 4, 1, 4)
        );
    }

}

/**
 * suite('Change Indentation to Tabs -  TypeScript/Javascript')
 */
class ChangeIndentationToTabsTest extends TestCase {

    function testSpacesOnlyAtStartOfLine() {
        IndentationTestUtils.testIndentationToTabsCommand(this,
            [
                '    first',
                'second line',
                '    third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 3, 2, 3),
            4,
            [
                '\tfirst',
                'second line',
                '\tthird line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 3, 2, 3)
        );
    }

    function testMultipleSpacesAtStartOfLine() {
        IndentationTestUtils.testIndentationToTabsCommand(this,
            [
                'first',
                '   second line',
                '          third line',
                'fourth line',
                '     fifth'
            ],
            new Selection(1, 5, 1, 5),
            3,
            [
                'first',
                '\tsecond line',
                '\t\t\t third line',
                'fourth line',
                '\t  fifth'
            ],
            new Selection(1, 5, 1, 5)
        );
    }

    function testMultipleSpaces() {
        IndentationTestUtils.testIndentationToTabsCommand(this,
            [
                '      first   ',
                '  second     line \t',
                '       third line',
                '   fourth line',
                'fifth'
            ],
            new Selection(1, 8, 1, 8),
            2,
            [
                '\t\t\tfirst   ',
                '\tsecond     line \t',
                '\t\t\t third line',
                '\t fourth line',
                'fifth'
            ],
            new Selection(1, 5, 1, 5)
        );
    }

    function testIssue45996() {
        IndentationTestUtils.testIndentationToSpacesCommand(this,
            [
                '\tabc',
            ],
            new Selection(1, 3, 1, 3),
            4,
            [
                '    abc',
            ],
            new Selection(1, 6, 1, 6)
        );
    }

}

/**
 * suite('Indent With Tab - TypeScript/JavaScript')
 *
 * Skipped in vscode (`test.skip`), not ported: 'issue #63388: perserve
 * correct indentation on tab 1' and '... tab 2'.
 */
class IndentWithTabTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.TypeScript);
    }

    function testTempIssueBecauseThereShouldBeAtLeastOnePassingTestInASuite() {
        assertTrue(true);
    }

}

/**
 * suite('Auto Indent On Paste - TypeScript/JavaScript')
 *
 * Skipped in vscode (`test.skip`, failing tests found in issues), not
 * ported: #181065, #86301, #85781, #29589, #201420.
 */
class AutoIndentOnPasteTypeScriptTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.TypeScript);
    }

    function testIssue119225DoNotAddExtraLeadingSpaceWhenPastingJSDoc() {

        final model = createTextModel("");
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            final pasteText = [
                '/**',
                ' * JSDoc',
                ' */',
                'function a() {}'
            ].join('\n');
            final tokens:Array<Array<StandardTokenTypeData>> = [
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Comment},
                    {startIndex: 3, standardTokenType: StandardTokenType.Comment},
                ],
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Comment},
                    {startIndex: 2, standardTokenType: StandardTokenType.Comment},
                    {startIndex: 8, standardTokenType: StandardTokenType.Comment},
                ],
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Comment},
                    {startIndex: 1, standardTokenType: StandardTokenType.Comment},
                    {startIndex: 3, standardTokenType: StandardTokenType.Other},
                ],
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other},
                    {startIndex: 8, standardTokenType: StandardTokenType.Other},
                    {startIndex: 9, standardTokenType: StandardTokenType.Other},
                    {startIndex: 10, standardTokenType: StandardTokenType.Other},
                    {startIndex: 11, standardTokenType: StandardTokenType.Other},
                    {startIndex: 12, standardTokenType: StandardTokenType.Other},
                    {startIndex: 13, standardTokenType: StandardTokenType.Other},
                    {startIndex: 14, standardTokenType: StandardTokenType.Other},
                    {startIndex: 15, standardTokenType: StandardTokenType.Other},
                ]
            ];
            disposables.add(registerTokenizationSupport(instantiationService, tokens, languageId));
            final autoIndentOnPasteController = editor.registerAndInstantiateContribution(AutoIndentOnPaste.ID, e -> new AutoIndentOnPaste(e));
            viewModel.paste(pasteText, true, null, 'keyboard');
            autoIndentOnPasteController.trigger(new Range(1, 1, 4, 16));
            assertEquals(pasteText, model.getValue());
        });
    }

    function testIssue167299BlankLineRemovesIndent() {

        final model = createTextModel("");
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {

            // no need for tokenization because there are no comments
            final pasteText = [
                '',
                'export type IncludeReference =',
                '	| BaseReference',
                '	| SelfReference',
                '	| RelativeReference;',
                '',
                'export const enum IncludeReferenceKind {',
                '	Base,',
                '	Self,',
                '	RelativeReference,',
                '}'
            ].join('\n');

            final autoIndentOnPasteController = editor.registerAndInstantiateContribution(AutoIndentOnPaste.ID, e -> new AutoIndentOnPaste(e));
            viewModel.paste(pasteText, true, null, 'keyboard');
            autoIndentOnPasteController.trigger(new Range(1, 1, 11, 2));
            assertEquals(pasteText, model.getValue());
        });
    }

    function testIssue29803DoNotIndentWhenPastingTextWithOnlyOneLine() {

        // https://github.com/microsoft/vscode/issues/29803

        final model = createTextModel([
            'const linkHandler = new Class(a, b, c,',
            '    d)'
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            editor.setSelection(new Selection(2, 6, 2, 6));
            final text = ', null';
            viewModel.paste(text, true, null, 'keyboard');
            final autoIndentOnPasteController = editor.registerAndInstantiateContribution(AutoIndentOnPaste.ID, e -> new AutoIndentOnPaste(e));
            autoIndentOnPasteController.trigger(new Range(2, 6, 2, 11));
            assertEquals([
                'const linkHandler = new Class(a, b, c,',
                '    d, null)'
            ].join('\n'), model.getValue());
        });
    }

    function testIssue29753IncorrectIndentationAfterComment() {

        // https://github.com/microsoft/vscode/issues/29753

        final model = createTextModel([
            'class A {',
            '    /**',
            '     * used only for debug purposes.',
            '     */',
            '    private _codeInfo: KeyMapping[];',
            '}',
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            editor.setSelection(new Selection(5, 24, 5, 34));
            final text = 'IMacLinuxKeyMapping';
            viewModel.paste(text, true, null, 'keyboard');
            final autoIndentOnPasteController = editor.registerAndInstantiateContribution(AutoIndentOnPaste.ID, e -> new AutoIndentOnPaste(e));
            autoIndentOnPasteController.trigger(new Range(5, 24, 5, 43));
            assertEquals([
                'class A {',
                '    /**',
                '     * used only for debug purposes.',
                '     */',
                '    private _codeInfo: IMacLinuxKeyMapping[];',
                '}',
            ].join('\n'), model.getValue());
        });
    }

    function testIssue29753IncorrectIndentationOfHeaderComment() {

        // https://github.com/microsoft/vscode/issues/29753

        final model = createTextModel('');
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            final text = [
                '/*----------------',
                ' *  Copyright (c) ',
                ' *  Licensed under ...',
                ' *-----------------*/',
            ].join('\n');
            viewModel.paste(text, true, null, 'keyboard');
            final autoIndentOnPasteController = editor.registerAndInstantiateContribution(AutoIndentOnPaste.ID, e -> new AutoIndentOnPaste(e));
            autoIndentOnPasteController.trigger(new Range(1, 1, 4, 22));
            assertEquals(text, model.getValue());
        });
    }

    function testIssue209859DoNotDoChangeIndentationWhenPastedInsideOfAString() {

        // issue: https://github.com/microsoft/vscode/issues/209859
        // issue: https://github.com/microsoft/vscode/issues/209418

        final initialText = [
            'const foo = "some text',
            '         which is strangely',
            '    indented"'
        ].join('\n');
        final model = createTextModel(initialText);
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            final tokens:Array<Array<StandardTokenTypeData>> = [
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other},
                    {startIndex: 12, standardTokenType: StandardTokenType.String},
                ],
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.String},
                ],
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.String},
                ]
            ];
            disposables.add(registerTokenizationSupport(instantiationService, tokens, languageId));

            editor.setSelection(new Selection(2, 10, 2, 15));
            viewModel.paste('which', true, null, 'keyboard');
            final autoIndentOnPasteController = editor.registerAndInstantiateContribution(AutoIndentOnPaste.ID, e -> new AutoIndentOnPaste(e));
            autoIndentOnPasteController.trigger(new Range(2, 1, 2, 28));
            assertEquals(initialText, model.getValue());
        });
    }

}

/**
 * suite('Auto Indent On Type - TypeScript/JavaScript')
 *
 * Skipped in vscode (`test.skip`, failing tests), not ported: the six
 * #43244 tests about equal signs, dots and semicolons, #40115, #193875,
 * #67678, #46401, #125261.
 */
class AutoIndentOnTypeTypeScriptTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.TypeScript);
    }

    // Failing tests from issues...

    function testIssue208215IndentAfterArrowFunction() {

        // https://github.com/microsoft/vscode/issues/208215

        final model = createTextModel("");
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, _) -> {
            viewModel.type('const add1 = (n) =>');
            viewModel.type("\n", 'keyboard');
            assertEquals([
                'const add1 = (n) =>',
                '    ',
            ].join('\n'), model.getValue());
        });
    }

    function testIssue208215IndentAfterArrowFunction2() {

        // https://github.com/microsoft/vscode/issues/208215

        final model = createTextModel([
            'const array = [1, 2, 3, 4, 5];',
            'array.map(',
            '    v =>',
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, _) -> {
            editor.setSelection(new Selection(3, 9, 3, 9));
            viewModel.type("\n", 'keyboard');
            assertEquals([
                'const array = [1, 2, 3, 4, 5];',
                'array.map(',
                '    v =>',
                '        '
            ].join('\n'), model.getValue());
        });
    }

    function testIssue116843IndentAfterArrowFunction() {

        // https://github.com/microsoft/vscode/issues/116843

        final model = createTextModel("");
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, _) -> {
            viewModel.type([
                'const add1 = (n) =>',
                '    n + 1;',
            ].join('\n'));
            viewModel.type("\n", 'keyboard');
            assertEquals([
                'const add1 = (n) =>',
                '    n + 1;',
                '',
            ].join('\n'), model.getValue());
        });
    }

    function testIssue29755DoNotAddIndentationOnEnterIfIndentationIsAlreadyValid() {

        //https://github.com/microsoft/vscode/issues/29755

        final model = createTextModel([
            'function f() {',
            '    const one = 1;',
            '    const two = 2;',
            '}',
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, _) -> {
            editor.setSelection(new Selection(3, 1, 3, 1));
            viewModel.type('\n', 'keyboard');
            assertEquals([
                'function f() {',
                '    const one = 1;',
                '',
                '    const two = 2;',
                '}',
            ].join('\n'), model.getValue());
        });
    }

    function testIssue36090() {

        // https://github.com/microsoft/vscode/issues/36090

        final model = createTextModel([
            'class ItemCtrl {',
            '    getPropertiesByItemId(id) {',
            '        return this.fetchItem(id)',
            '            .then(item => {',
            '                return this.getPropertiesOfItem(item);',
            '            });',
            '    }',
            '}',
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'advanced', (editor, viewModel, _) -> {
            editor.setSelection(new Selection(7, 6, 7, 6));
            viewModel.type('\n', 'keyboard');
            assertEquals(
                [
                    'class ItemCtrl {',
                    '    getPropertiesByItemId(id) {',
                    '        return this.fetchItem(id)',
                    '            .then(item => {',
                    '                return this.getPropertiesOfItem(item);',
                    '            });',
                    '    }',
                    '    ',
                    '}',
                ].join('\n'),
                model.getValue()
            );
            assertEquals(new Selection(8, 5, 8, 5).toString(), editor.getSelection().toString());
        });
    }

    function testIssue115304IndentBlockCommentOnEnter() {

        // https://github.com/microsoft/vscode/issues/115304

        final model = createTextModel([
            '/** */',
            'function f() {}',
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'advanced', (editor, viewModel, _) -> {
            editor.setSelection(new Selection(1, 4, 1, 4));
            viewModel.type('\n', 'keyboard');
            assertEquals(
                [
                    '/**',
                    ' * ',
                    ' */',
                    'function f() {}',
                ].join('\n'),
                model.getValue()
            );
            assertEquals(new Selection(2, 4, 2, 4).toString(), editor.getSelection().toString());
        });
    }

    function testIssue43244IndentWhenLambdaArrowFunctionIsDetectedOutdentWhenEndIsReached() {

        // https://github.com/microsoft/vscode/issues/43244

        final model = createTextModel([
            'const array = [1, 2, 3, 4, 5];',
            'array.map(_)'
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, _) -> {
            editor.setSelection(new Selection(2, 12, 2, 12));
            viewModel.type("\n", 'keyboard');
            assertEquals([
                'const array = [1, 2, 3, 4, 5];',
                'array.map(_',
                '    ',
                ')'
            ].join('\n'), model.getValue());
        });
    }

    function testIssue43244IncorrectIndentationAfterIfForWhileWithoutBraces() {

        // https://github.com/microsoft/vscode/issues/43244

        final model = createTextModel([
            'function f() {',
            '    if (condition)',
            '}'
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, _) -> {
            editor.setSelection(new Selection(2, 19, 2, 19));
            viewModel.type("\n", 'keyboard');
            assertEquals([
                'function f() {',
                '    if (condition)',
                '        ',
                '}',
            ].join('\n'), model.getValue());

            viewModel.type("return;");
            viewModel.type("\n", 'keyboard');
            assertEquals([
                'function f() {',
                '    if (condition)',
                '        return;',
                '    ',
                '}',
            ].join('\n'), model.getValue());
        });
    }

    function testIssue208232IncorrectIndentationInsideOfComments() {

        // https://github.com/microsoft/vscode/issues/208232

        final model = createTextModel([
            '/**',
            'indentation done for {',
            '*/'
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            final tokens:Array<Array<StandardTokenTypeData>> = [
                [{startIndex: 0, standardTokenType: StandardTokenType.Comment}],
                [{startIndex: 0, standardTokenType: StandardTokenType.Comment}],
                [{startIndex: 0, standardTokenType: StandardTokenType.Comment}]
            ];
            disposables.add(registerTokenizationSupport(instantiationService, tokens, languageId));
            editor.setSelection(new Selection(2, 23, 2, 23));
            viewModel.type("\n", 'keyboard');
            assertEquals([
                '/**',
                'indentation done for {',
                '',
                '*/'
            ].join('\n'), model.getValue());
        });
    }

    function testIssue209802AllmanStyleBracesInJavaScript() {

        // https://github.com/microsoft/vscode/issues/209802

        final model = createTextModel([
            'if (/*condition*/)',
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, _) -> {
            editor.setSelection(new Selection(1, 19, 1, 19));
            viewModel.type("\n", 'keyboard');
            assertEquals([
                'if (/*condition*/)',
                '    '
            ].join('\n'), model.getValue());
            viewModel.type("{", 'keyboard');
            assertEquals([
                'if (/*condition*/)',
                '{}'
            ].join('\n'), model.getValue());
            editor.setSelection(new Selection(2, 2, 2, 2));
            viewModel.type("\n", 'keyboard');
            assertEquals([
                'if (/*condition*/)',
                '{',
                '    ',
                '}'
            ].join('\n'), model.getValue());
        });
    }

}

/**
 * suite('Auto Indent On Type - Ruby')
 *
 * Skipped in vscode (`test.skip`), not ported: #199846.
 */
class AutoIndentOnTypeRubyTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.Ruby);
    }

    function testIssue198350InOrWhenIncorrectlyMatchNonKeywordsForRuby() {

        // https://github.com/microsoft/vscode/issues/198350

        final model = createTextModel("");
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, _) -> {
            viewModel.type("def foo\n        i");
            viewModel.type("n", 'keyboard');
            assertEquals("def foo\n        in", model.getValue());
            viewModel.type(" ", 'keyboard');
            assertEquals("def foo\nin ", model.getValue());

            viewModel.model.setValue("");
            viewModel.type("  # in");
            assertEquals("  # in", model.getValue());
            viewModel.type(" ", 'keyboard');
            assertEquals("  # in ", model.getValue());
        });
    }

}

/**
 * suite('Auto Indent On Type - PHP')
 */
class AutoIndentOnTypePHPTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.PHP);
    }

    function testIssue199050ShouldNotIndentAfterBraceDetectedInAString() {

        // https://github.com/microsoft/vscode/issues/199050

        final model = createTextModel("preg_replace('{');");
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            final tokens:Array<Array<StandardTokenTypeData>> = [
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other},
                    {startIndex: 13, standardTokenType: StandardTokenType.String},
                    {startIndex: 16, standardTokenType: StandardTokenType.Other},
                ]
            ];
            disposables.add(registerTokenizationSupport(instantiationService, tokens, languageId));
            editor.setSelection(new Selection(1, 54, 1, 54));
            viewModel.type("\n", 'keyboard');
            assertEquals([
                "preg_replace('{');",
                ""
            ].join('\n'), model.getValue());
        });
    }

}

/**
 * suite('Auto Indent On Paste - Go')
 *
 * Skipped in vscode (`test.skip`), not ported: #199050.
 */
class AutoIndentOnPasteGoTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.Go);
    }

    function testTempIssueBecauseThereShouldBeAtLeastOnePassingTestInASuite() {
        assertTrue(true);
    }

}

/**
 * suite('Auto Indent On Type - CPP')
 *
 * Skipped in vscode (`test.skip`), not ported: #178334, #118929, #111265.
 */
class AutoIndentOnTypeCPPTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.CPP);
    }

    function testTempIssueBecauseThereShouldBeAtLeastOnePassingTestInASuite() {
        assertTrue(true);
    }

}

/**
 * suite('Auto Indent On Type - HTML')
 *
 * Skipped in vscode (`test.skip`), not ported: #61510.
 */
class AutoIndentOnTypeHTMLTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.HTML);
    }

    function testTempIssueBecauseThereShouldBeAtLeastOnePassingTestInASuite() {
        assertTrue(true);
    }

}

/**
 * suite('Auto Indent On Type - Visual Basic')
 *
 * Skipped in vscode (`test.skip`), not ported: #118932.
 */
class AutoIndentOnTypeVisualBasicTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.VB);
    }

    function testTempIssueBecauseThereShouldBeAtLeastOnePassingTestInASuite() {
        assertTrue(true);
    }

}

/**
 * suite('Auto Indent On Type - Latex')
 *
 * Skipped in vscode (`test.skip`), not ported: #178075.
 */
class AutoIndentOnTypeLatexTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.Latex);
    }

    function testTempIssueBecauseThereShouldBeAtLeastOnePassingTestInASuite() {
        assertTrue(true);
    }

}

/**
 * suite('Auto Indent On Type - Lua')
 *
 * Skipped in vscode (`test.skip`), not ported: #178075.
 */
class AutoIndentOnTypeLuaTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.Lua);
    }

    function testTempIssueBecauseThereShouldBeAtLeastOnePassingTestInASuite() {
        assertTrue(true);
    }

}
