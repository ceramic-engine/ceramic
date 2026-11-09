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

    }

}
