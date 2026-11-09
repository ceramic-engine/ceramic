// Ported from vscode src/vs/editor/contrib/indentation/test/browser/indentationLineProcessor.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.indentation;

// Classes of this module (one per suite of vscode):
// - IndentationContextProcessorTest
// - ProcessedIndentRulesSupportTest

import cityscape.common.EncodedTokenAttributes;
import cityscape.common.core.Range;
import cityscape.common.languages.AutoIndent.TextModelVirtualModel;
import cityscape.common.languages.supports.IndentationLineProcessor;
import tests.contrib.indentation.IndentationTest;

/**
 * suite('Indentation Context Processor - TypeScript/JavaScript')
 */
class IndentationContextProcessorTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.TypeScript);
    }

    function testBracketsInsideOfString() {

        final model = createTextModel([
            'const someVar = "{some text}"',
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            final tokens:Array<Array<StandardTokenTypeData>> = [[
                {startIndex: 0, standardTokenType: StandardTokenType.Other},
                {startIndex: 16, standardTokenType: StandardTokenType.String},
                {startIndex: 28, standardTokenType: StandardTokenType.String}
            ]];
            disposables.add(registerTokenizationSupport(instantiationService, tokens, languageId));
            final languageConfigurationService = instantiationService.languageConfigurationService;
            final indentationContextProcessor = new IndentationContextProcessor(model, languageConfigurationService);
            final processedContext = indentationContextProcessor.getProcessedTokenContextAroundRange(new Range(1, 23, 1, 23));
            assertEquals('const someVar = "some', processedContext.beforeRangeProcessedTokens.getLineContent());
            assertEquals(' text"', processedContext.afterRangeProcessedTokens.getLineContent());
            assertEquals('', processedContext.previousLineProcessedTokens.getLineContent());
        });
    }

    function testBracketsInsideOfComment() {

        final model = createTextModel([
            'const someVar2 = /*(a])*/',
            'const someVar = /* [()] some other t{e}xt() */ "some text"',
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            final tokens:Array<Array<StandardTokenTypeData>> = [
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other},
                    {startIndex: 17, standardTokenType: StandardTokenType.Comment},
                ],
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other},
                    {startIndex: 16, standardTokenType: StandardTokenType.Comment},
                    {startIndex: 46, standardTokenType: StandardTokenType.Other},
                    {startIndex: 47, standardTokenType: StandardTokenType.String}
                ]];
            disposables.add(registerTokenizationSupport(instantiationService, tokens, languageId));
            final languageConfigurationService = instantiationService.languageConfigurationService;
            final indentationContextProcessor = new IndentationContextProcessor(model, languageConfigurationService);
            final processedContext = indentationContextProcessor.getProcessedTokenContextAroundRange(new Range(2, 29, 2, 35));
            assertEquals('const someVar = /*  some', processedContext.beforeRangeProcessedTokens.getLineContent());
            assertEquals(' text */ "some text"', processedContext.afterRangeProcessedTokens.getLineContent());
            assertEquals('const someVar2 = /*a*/', processedContext.previousLineProcessedTokens.getLineContent());
        });
    }

    function testBracketsInsideOfRegex() {

        final model = createTextModel([
            'const someRegex2 = /(()))]/;',
            'const someRegex = /()a{h}{s}[(a}87(9a9()))]/;',
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            final tokens:Array<Array<StandardTokenTypeData>> = [
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other},
                    {startIndex: 19, standardTokenType: StandardTokenType.RegEx},
                    {startIndex: 27, standardTokenType: StandardTokenType.Other},
                ],
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other},
                    {startIndex: 18, standardTokenType: StandardTokenType.RegEx},
                    {startIndex: 44, standardTokenType: StandardTokenType.Other},
                ]
            ];
            disposables.add(registerTokenizationSupport(instantiationService, tokens, languageId));
            final languageConfigurationService = instantiationService.languageConfigurationService;
            final indentationContextProcessor = new IndentationContextProcessor(model, languageConfigurationService);
            final processedContext = indentationContextProcessor.getProcessedTokenContextAroundRange(new Range(1, 25, 2, 33));
            assertEquals('const someRegex2 = /', processedContext.beforeRangeProcessedTokens.getLineContent());
            assertEquals('879a9/;', processedContext.afterRangeProcessedTokens.getLineContent());
            assertEquals('', processedContext.previousLineProcessedTokens.getLineContent());
        });
    }

}

/**
 * suite('Processed Indent Rules Support - TypeScript/JavaScript')
 */
class ProcessedIndentRulesSupportTest extends IndentationLanguageSuite {

    public function new() {
        super(Language.TypeScript);
    }

    function testShouldIncrease() {

        final model = createTextModel([
            'const someVar = {',
            'const someVar2 = "{"',
            'const someVar3 = /*{*/'
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            final tokens:Array<Array<StandardTokenTypeData>> = [
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other}
                ],
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other},
                    {startIndex: 17, standardTokenType: StandardTokenType.String},
                ],
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other},
                    {startIndex: 17, standardTokenType: StandardTokenType.Comment},
                ]
            ];
            disposables.add(registerTokenizationSupport(instantiationService, tokens, languageId));
            final languageConfigurationService = instantiationService.languageConfigurationService;
            final indentationRulesSupport = languageConfigurationService.getLanguageConfiguration(languageId).indentRulesSupport;
            if (indentationRulesSupport == null) {
                fail('indentationRulesSupport should be defined');
                return;
            }
            final processedIndentRulesSupport = new ProcessedIndentRulesSupport(new TextModelVirtualModel(model), indentationRulesSupport, languageConfigurationService);
            assertEquals(true, processedIndentRulesSupport.shouldIncrease(1));
            assertEquals(false, processedIndentRulesSupport.shouldIncrease(2));
            assertEquals(false, processedIndentRulesSupport.shouldIncrease(3));
        });
    }

    function testShouldDecrease() {

        final model = createTextModel([
            '}',
            '"])some text}"',
            '])*/'
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            final tokens:Array<Array<StandardTokenTypeData>> = [
                [{startIndex: 0, standardTokenType: StandardTokenType.Other}],
                [{startIndex: 0, standardTokenType: StandardTokenType.String}],
                [{startIndex: 0, standardTokenType: StandardTokenType.Comment}]
            ];
            disposables.add(registerTokenizationSupport(instantiationService, tokens, languageId));
            final languageConfigurationService = instantiationService.languageConfigurationService;
            final indentationRulesSupport = languageConfigurationService.getLanguageConfiguration(languageId).indentRulesSupport;
            if (indentationRulesSupport == null) {
                fail('indentationRulesSupport should be defined');
                return;
            }
            final processedIndentRulesSupport = new ProcessedIndentRulesSupport(new TextModelVirtualModel(model), indentationRulesSupport, languageConfigurationService);
            assertEquals(true, processedIndentRulesSupport.shouldDecrease(1));
            assertEquals(false, processedIndentRulesSupport.shouldDecrease(2));
            assertEquals(false, processedIndentRulesSupport.shouldDecrease(3));
        });
    }

    function testShouldIncreaseNextLine() {

        final model = createTextModel([
            'if()',
            'const someString = "if()"',
            'const someRegex = /if()/'
        ].join('\n'));
        disposables.add(model);

        withTestCodeEditor(model, 'full', (editor, viewModel, instantiationService) -> {
            final tokens:Array<Array<StandardTokenTypeData>> = [
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other}
                ],
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other},
                    {startIndex: 19, standardTokenType: StandardTokenType.String}
                ],
                [
                    {startIndex: 0, standardTokenType: StandardTokenType.Other},
                    {startIndex: 18, standardTokenType: StandardTokenType.RegEx}
                ]
            ];
            disposables.add(registerTokenizationSupport(instantiationService, tokens, languageId));
            final languageConfigurationService = instantiationService.languageConfigurationService;
            final indentationRulesSupport = languageConfigurationService.getLanguageConfiguration(languageId).indentRulesSupport;
            if (indentationRulesSupport == null) {
                fail('indentationRulesSupport should be defined');
                return;
            }
            final processedIndentRulesSupport = new ProcessedIndentRulesSupport(new TextModelVirtualModel(model), indentationRulesSupport, languageConfigurationService);
            assertEquals(true, processedIndentRulesSupport.shouldIndentNextLine(1));
            assertEquals(false, processedIndentRulesSupport.shouldIndentNextLine(2));
            assertEquals(false, processedIndentRulesSupport.shouldIndentNextLine(3));
        });
    }

}
