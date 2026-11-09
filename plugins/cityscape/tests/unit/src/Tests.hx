package;

import testing.TestRunner;

/**
 * List of all unit test cases. Add new test classes here.
 */
class Tests {

    public static function register(runner:TestRunner):Void {

        runner.add(new tests.PluginSetupTest());
        runner.add(new tests.HaxeStringTest());
        runner.add(new tests.InterfacesTest());
        runner.add(new tests.core.RangeTest());
        runner.add(new tests.config.EditorConfigurationTest());
        runner.add(new tests.config.MigrateOptionsTest());
        runner.add(new tests.config.EditorOptionsTruthTest());
        runner.add(new tests.base.RegExpTest());
        runner.add(new tests.viewModel.PrefixSumComputerTest());
        runner.add(new tests.model.TextChangeTest.TextChangeCompressorTest());
        runner.add(new tests.model.TextChangeTest());
        runner.add(new tests.model.EditStackTest());
        runner.add(new tests.model.EditableTextModelTest.EditorModelEditableTextModelApplyEditsUpdatesMightContainRTLTest());
        runner.add(new tests.model.EditableTextModelTest.EditorModelEditableTextModelApplyEditsUpdatesMightContainNonBasicASCIITest());
        runner.add(new tests.model.EditableTextModelTest.EditorModelEditableTextModelApplyEditsTest());
        runner.add(new tests.model.EditableTextModelAutoTest.EditorModelAutoTestsTest());
        runner.add(new tests.model.TextModelSearchTest());
        runner.add(new tests.model.TextModelTest.TextModelDataFromStringTest());
        runner.add(new tests.model.TextModelTest.EditorModelTextModelTest());
        runner.add(new tests.model.TextModelTest.TextModelMightContainRTLTest());
        runner.add(new tests.model.TextModelTest.TextModelCreateSnapshotTest());
        runner.add(new tests.model.ModelTest.EditorModelModelTest());
        runner.add(new tests.model.ModelTest.EditorModelModelLineSeparatorsTest());
        runner.add(new tests.model.ModelTest.EditorModelWordsTest());
        runner.add(new tests.model.ModelEditOperationTest.EditorModelModelEditOperationTest());
        runner.add(new tests.model.ModelLineTest.ModelLineGetIndentLevelTest());
        runner.add(new tests.model.TextModelGuidesTest.TextModelGetLineIndentGuideTest());
        runner.add(new tests.model.IntervalTreeTest.IntervalTree1GeneratedTest());
        runner.add(new tests.model.IntervalTreeTest.IntervalTree1SearchingTest());
        runner.add(new tests.model.IntervalTreeTest.IntervalTree2Test());
        runner.add(new tests.model.ModelDecorationsTest.EditorModelModelDecorationsTest());
        runner.add(new tests.model.ModelDecorationsTest.DecorationsAndEditingInsertCollapsedDecTest());
        runner.add(new tests.model.ModelDecorationsTest.DecorationsAndEditingInsertNonCollapsedDecTest());
        runner.add(new tests.model.ModelDecorationsTest.DecorationsAndEditingDeleteCollapsedDecTest());
        runner.add(new tests.model.ModelDecorationsTest.DecorationsAndEditingDeleteNonCollapsedDecTest());
        runner.add(new tests.model.ModelDecorationsTest.DecorationsAndEditingReplaceShortCollapsedDecTest());
        runner.add(new tests.model.ModelDecorationsTest.DecorationsAndEditingReplaceShortNonCollapsedDecTest());
        runner.add(new tests.model.ModelDecorationsTest.DecorationsAndEditingReplaceLongCollapsedDecTest());
        runner.add(new tests.model.ModelDecorationsTest.DecorationsAndEditingReplaceLongNonCollapsedDecTest());
        runner.add(new tests.model.ModelDecorationsTest.DeltaDecorationsTest());
        runner.add(new tests.model.ModelInjectedTextTest.EditorModelInjectedTextEventsTest());
        runner.add(new tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.InsertsAndDeletesTest());
        runner.add(new tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.PrefixSumForLineFeedTest());
        runner.add(new tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.Offset2PositionTest());
        runner.add(new tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.GetTextInRangeTest());
        runner.add(new tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.CRLFTest());
        runner.add(new tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.CentralizedLineStartsWithCRLFTest());
        runner.add(new tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.RandomIsUnsupervisedTest());
        runner.add(new tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.BufferApiTest());
        runner.add(new tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.SearchOffsetCacheTest());
        runner.add(new tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.SnapshotTest());
        runner.add(new tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.ChunkBasedSearchTest());
        runner.add(new tests.model.pieceTreeTextBuffer.ChangeBufferTest());
        runner.add(new tests.model.TextModelTokensTest());
        runner.add(new tests.model.ModelModesTest());
        runner.add(new tests.model.ModelModesTest.ModelModes2Test());
        runner.add(new tests.model.TokensStoreTest());
        runner.add(new tests.model.TokensStoreModelTest());
        runner.add(new tests.model.TextModelWithTokensTest());
        runner.add(new tests.model.TextModelWithTokensBracketsTest());
        runner.add(new tests.model.ModelLinesTokensTest());
        runner.add(new tests.model.ModelWordsLanguagesTest());
        runner.add(new tests.textmate.TextMateTruthTest());
        runner.add(new tests.textmate.TextMateServiceTest());
        runner.add(new tests.base.ColorTest());
        runner.add(new tests.modes.supports.TokenizationTest());
        runner.add(new tests.theme.ColorRegistryTest());
        runner.add(new tests.standalone.StandaloneThemeServiceTest());
        runner.add(new tests.standalone.VSCodeThemeTest());
        runner.add(new tests.modes.LanguageConfigurationTest());
        runner.add(new tests.modes.supports.CharacterPairTest());
        runner.add(new tests.modes.supports.ElectricCharacterTest());
        runner.add(new tests.modes.supports.OnEnterTest());
        runner.add(new tests.modes.supports.RichEditBracketsTest());
        runner.add(new tests.model.bracketPairColorizer.LengthTest());
        runner.add(new tests.model.bracketPairColorizer.SmallImmutableSetTest());
        runner.add(new tests.model.bracketPairColorizer.BracketsTest());
        runner.add(new tests.model.bracketPairColorizer.Concat23TreesTest());
        runner.add(new tests.model.bracketPairColorizer.BeforeEditPositionMapperTest());
        runner.add(new tests.model.bracketPairColorizer.CombineTextEditInfosTest());
        runner.add(new tests.model.bracketPairColorizer.TokenizerTest());
        runner.add(new tests.model.bracketPairColorizer.GetBracketPairsInRangeTest());
        runner.add(new tests.viewModel.LineBreakDataTest());
        runner.add(new tests.viewModel.MonospaceLineBreaksComputerTest());
        runner.add(new tests.viewLayout.LinesLayoutTest());
        runner.add(new tests.viewLayout.LineDecorationsTest());
        runner.add(new tests.viewLayout.ViewLineRendererTest());
        runner.add(new tests.viewModel.GlyphLanesModelTest());
        runner.add(new tests.viewModel.ModelLineProjectionTest());
        runner.add(new tests.viewModel.ViewModelHiddenRangesTest());
        runner.add(new tests.view.CityscapeEditorTest());
        runner.add(new tests.view.WideColumnsTest());

        // Cursor (step 3, cs3-cursor)
        runner.add(new tests.base.StringsTest());
        runner.add(new tests.controller.CursorMoveHelperTest());
        runner.add(new tests.controller.CursorAtomicMoveOperationsTest());
        runner.add(new tests.controller.CursorMoveCommandTest());
        runner.add(new tests.controller.CursorMoveCommandTest.CursorMoveByBlanklineTest());
        runner.add(new tests.controller.CursorTest.EditorControllerCursorTest());
        runner.add(new tests.controller.CursorTest.EditorControllerTest());
        runner.add(new tests.controller.CursorTest.UndoStopsTest());
        runner.add(new tests.commands.SideEditingTest.EditorSideEditingCollapsedSelectionTest());
        runner.add(new tests.commands.SideEditingTest());
        runner.add(new tests.commands.TrimTrailingWhitespaceCommandTest());
        runner.add(new tests.commands.ShiftCommandTest());
        runner.add(new tests.contrib.wordOperations.WordOperationsTest());
        runner.add(new tests.contrib.find.ReplacePatternTest());
        runner.add(new tests.contrib.find.FindTest());
        runner.add(new tests.contrib.find.FindModelTest());
        runner.add(new tests.contrib.find.FindControllerTest());
        runner.add(new tests.contrib.bracketMatching.BracketMatchingTest());
        runner.add(new tests.contrib.wordHighlighter.WordHighlighterTest());
        runner.add(new tests.contrib.multicursor.MulticursorTest());
        runner.add(new tests.contrib.stickyScroll.StickyScrollTest());
        runner.add(new tests.view.BracketPairColorsTest());
        runner.add(new tests.contrib.find.FindWidgetTest());

        // Folding (step 4, cs4-fold)
        runner.add(new tests.contrib.folding.FoldingRangesTest());
        runner.add(new tests.contrib.folding.IndentRangeProviderTest());
        runner.add(new tests.contrib.folding.IndentRangeProviderTest.FoldingWithRegionsTest());
        runner.add(new tests.contrib.folding.IndentFoldTest());
        runner.add(new tests.contrib.folding.SyntaxFoldTest());
        runner.add(new tests.contrib.folding.HiddenRangeModelTest());
        runner.add(new tests.contrib.folding.FoldingModelTest());
        runner.add(new tests.contrib.folding.FoldingControllerTest());
        runner.add(new tests.contrib.comment.BlockCommentCommandTest());
        runner.add(new tests.contrib.comment.LineCommentCommandTest());
        runner.add(new tests.contrib.comment.LineCommentCommandTest.IgnoreEmptyLinesFalseTest());
        runner.add(new tests.contrib.comment.LineCommentCommandTest.EditorContribLineCommentAsBlockCommentTest());
        runner.add(new tests.contrib.comment.LineCommentCommandTest.EditorContribLineCommentAsBlockComment2Test());
        runner.add(new tests.contrib.comment.LineCommentCommandTest.EditorContribLineCommentInMixedModesTest());
        runner.add(new tests.contrib.linesOperations.CopyLinesCommandTest());
        runner.add(new tests.contrib.linesOperations.CopyLinesCommandTest.EditorContribDuplicateSelectionTest());
        runner.add(new tests.contrib.linesOperations.MoveLinesCommandTest());
        runner.add(new tests.contrib.linesOperations.MoveLinesCommandTest.EditorContribMoveLinesCommandHonorsIndentationRulesTest());
        runner.add(new tests.contrib.linesOperations.MoveLinesCommandTest.EditorContribMoveLinesCommandHonorsOnEnterRulesTest());
        runner.add(new tests.contrib.linesOperations.SortLinesCommandTest());
        runner.add(new tests.contrib.linesOperations.LinesOperationsTest());
        runner.add(new tests.contrib.linesOperations.LinesOperationsTest.SortLinesAscendingActionTest());
        runner.add(new tests.contrib.linesOperations.LinesOperationsTest.SortLinesDescendingActionTest());
        runner.add(new tests.contrib.linesOperations.LinesOperationsTest.DeleteDuplicateLinesActionTest());
        runner.add(new tests.contrib.linesOperations.LinesOperationsTest.DeleteAllLeftActionTest());
        runner.add(new tests.contrib.linesOperations.LinesOperationsTest.JoinLinesActionTest());
        runner.add(new tests.contrib.linesOperations.LinesOperationsTest.DeleteAllRightActionTest());

        // Commands, keybindings, context keys, editor API (step 3, cs3-api)
        runner.add(new tests.platform.contextkey.ContextKeyScannerTest());
        runner.add(new tests.platform.contextkey.ContextKeyParserTest());
        runner.add(new tests.platform.contextkey.ContextKeyExprTest());
        runner.add(new tests.platform.keybinding.KeybindingResolverTest());
        runner.add(new tests.platform.markers.MarkerServiceTest());
        runner.add(new tests.view.CityscapeApiTest());

        // Indentation, smart select, caret operations, cursor undo, in place replace (step 4, cs4-edit)
        runner.add(new tests.contrib.indentation.IndentationTest.ChangeIndentationToSpacesTest());
        runner.add(new tests.contrib.indentation.IndentationTest.ChangeIndentationToTabsTest());
        runner.add(new tests.contrib.indentation.IndentationTest.IndentWithTabTest());
        runner.add(new tests.contrib.indentation.IndentationTest.AutoIndentOnPasteTypeScriptTest());
        runner.add(new tests.contrib.indentation.IndentationTest.AutoIndentOnTypeTypeScriptTest());
        runner.add(new tests.contrib.indentation.IndentationTest.AutoIndentOnTypeRubyTest());
        runner.add(new tests.contrib.indentation.IndentationTest.AutoIndentOnTypePHPTest());
        runner.add(new tests.contrib.indentation.IndentationTest.AutoIndentOnPasteGoTest());
        runner.add(new tests.contrib.indentation.IndentationTest.AutoIndentOnTypeCPPTest());
        runner.add(new tests.contrib.indentation.IndentationTest.AutoIndentOnTypeHTMLTest());
        runner.add(new tests.contrib.indentation.IndentationTest.AutoIndentOnTypeVisualBasicTest());
        runner.add(new tests.contrib.indentation.IndentationTest.AutoIndentOnTypeLatexTest());
        runner.add(new tests.contrib.indentation.IndentationTest.AutoIndentOnTypeLuaTest());
        runner.add(new tests.contrib.indentation.IndentationLineProcessorTest.IndentationContextProcessorTest());
        runner.add(new tests.contrib.indentation.IndentationLineProcessorTest.ProcessedIndentRulesSupportTest());
        runner.add(new tests.contrib.smartSelect.SmartSelectTest());
        runner.add(new tests.contrib.caretOperations.MoveCaretCommandTest());
        runner.add(new tests.contrib.cursorUndo.CursorUndoTest());

        // Language features (step 4, cs4-lang)
        runner.add(new tests.base.FiltersTest());
        runner.add(new tests.contrib.snippet.SnippetParserTest());
        runner.add(new tests.contrib.suggest.CompletionModelTest());
        runner.add(new tests.contrib.suggest.SuggestTest());
        runner.add(new tests.contrib.suggest.SuggestModelTest());
        runner.add(new tests.lsp.LspConversionsTest());
        runner.add(new tests.lsp.LspClientTest());
        runner.add(new tests.contrib.documentSymbols.OutlineModelTest());
        runner.add(new tests.contrib.LanguageFeaturesTest());
        runner.add(new tests.contrib.gotoSymbol.ReferencesModelTest());
        runner.add(new tests.contrib.codeAction.CodeActionTest());
        runner.add(new tests.contrib.codeAction.CodeActionKeybindingResolverTest());

    }

}
