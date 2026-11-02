package;

import testing.TestRunner;

/**
 * List of all unit test cases. Add new test classes here.
 */
class Tests {

    public static function register(runner:TestRunner):Void {

        runner.add(new tests.GpuiTest());
        runner.add(new tests.GeometryTest());
        runner.add(new tests.ColorTest());
        runner.add(new tests.SceneTest());
        runner.add(new tests.SceneDamageTest());
        runner.add(new tests.AppTest());
        runner.add(new tests.ReactivityTest());
        runner.add(new tests.EffectsOrderTest());
        runner.add(new tests.StyleTest());
        runner.add(new tests.LayoutTest());
        runner.add(new tests.WindowTest());
        runner.add(new tests.AnimationTest());
        runner.add(new tests.SpringTest());
        runner.add(new tests.KeystrokeTest());
        runner.add(new tests.KeyContextTest());
        runner.add(new tests.KeymapTest());
        runner.add(new tests.ActionTest());
        runner.add(new tests.InteractionBehaviourTest());
        runner.add(new tests.AnimationElementTest());
        runner.add(new tests.TextSystemTest());
        runner.add(new tests.LineLayoutTest());
        runner.add(new tests.LineWrapperTest());
        runner.add(new tests.SystemFontFallbackTest());
        runner.add(new tests.CanvasFallbackTest());
        runner.add(new tests.BundledEmojiFontTest());
        runner.add(new tests.TabStopTest());
        runner.add(new tests.KeyDispatchWindowTest());
        runner.add(new tests.DivInteractivityTest());
        runner.add(new tests.TouchGestureTest());
        runner.add(new tests.TouchWindowTest());
        runner.add(new tests.GpuiInputTouchTest());
        runner.add(new tests.kit.InputTouchTest());
        runner.add(new tests.kit.TouchSelectionIntegrationTest());
        runner.add(new tests.WindowFocusTest());
        // GPUI's inspector (define gpui_inspector)
        #if gpui_inspector
        runner.add(new tests.InspectorTest());
        #end
        runner.add(new tests.InteractiveTest());
        runner.add(new tests.TextElementTest());
        runner.add(new tests.SvgPathTest());
        runner.add(new tests.PathTessellatorTest());
        runner.add(new tests.ColorHelpersTest());
        runner.add(new tests.ThemeTest());
        runner.add(new tests.I18nTest());
        runner.add(new tests.ListTest());
        runner.add(new tests.UniformListTest());
        runner.add(new tests.AnchoredTest());
        runner.add(new tests.ImgTest());
        #if plugin_http
        runner.add(new tests.CeramicHttpClientTest());
        #end
        runner.add(new tests.AtlasAllocatorTest());
        runner.add(new tests.RenderCacheTest());
        runner.add(new tests.InputHandlerTest());
        runner.add(new tests.TextInputBehaviourTest());
        runner.add(new tests.ViewCacheTest());
        // gpui-kit (waves 1 and 2)
        runner.add(new tests.kit.BaseRootTest());
        runner.add(new tests.kit.FrameScheduleTest());
        runner.add(new tests.kit.BaseFoundationsTest());
        runner.add(new tests.kit.EasingsTest());
        runner.add(new tests.kit.EasingTest());
        runner.add(new tests.kit.MotionTest());
        runner.add(new tests.kit.HistoryTest());
        runner.add(new tests.kit.UndoHistoryTest());
        runner.add(new tests.kit.ReduceMotionTest());
        runner.add(new tests.kit.NavStackTest());
        runner.add(new tests.kit.MotionElementsTest());
        runner.add(new tests.kit.ComponentFoundationsTest());
        runner.add(new tests.kit.ComponentLeavesTest());
        // gpui-kit (wave 3)
        runner.add(new tests.kit.BaseControlsTest());
        runner.add(new tests.kit.ComponentControlsTest());
        // gpui-kit (wave 4)
        runner.add(new tests.kit.BaseScrollbarTest());
        runner.add(new tests.kit.BaseScrollTest());
        runner.add(new tests.kit.ComponentScrollTest());
        // gpui-kit (wave 5: menus)
        runner.add(new tests.AppMenuTest());
        runner.add(new tests.kit.ComponentMenuTest());
        // gpui-kit (wave 5: modals)
        runner.add(new tests.kit.BaseModalsTest());
        runner.add(new tests.kit.ComponentModalsTest());
        // gpui-kit (wave 5: popovers, tooltips, hover cards)
        runner.add(new tests.kit.BaseOverlaysTest());
        runner.add(new tests.kit.ComponentOverlaysTest());
        // gpui-kit (wave 6: input engine base)
        runner.add(new tests.kit.InputRopeExtTest());
        runner.add(new tests.kit.InputMaskPatternTest());
        runner.add(new tests.kit.InputCursorTest());
        runner.add(new tests.kit.InputSelectionTest());
        runner.add(new tests.kit.InputUndoManagerTest());
        runner.add(new tests.kit.InputTabStopsTest());
        runner.add(new tests.kit.InputBlinkCursorTest());
        runner.add(new tests.kit.InputBaseTest());
        runner.add(new tests.kit.InputTouchSelectionTest());
        runner.add(new tests.kit.InputKeyBindingsTest());
        // gpui-kit (wave 6: input engine editor support)
        runner.add(new tests.kit.InputIndentTest());
        runner.add(new tests.kit.InputHighlightingTest());
        runner.add(new tests.kit.InputDiagnosticsTest());
        runner.add(new tests.kit.InputDecorationsTest());
        runner.add(new tests.kit.InputSearchTest());
        runner.add(new tests.kit.InputFoldMapTest());
        runner.add(new tests.kit.InputTextWrapperTest());
        runner.add(new tests.kit.InputWrapWidthTest());
        runner.add(new tests.kit.InputTextElementTest());
        // gpui-kit (wave 6: input state, Input, Textarea)
        runner.add(new tests.kit.InputModeTest());
        runner.add(new tests.kit.InputLspTest());
        runner.add(new tests.kit.InputStateTest());
        runner.add(new tests.kit.InputMoveNotifyTest());
        runner.add(new tests.kit.InputStateEditingTest());
        runner.add(new tests.kit.InputEmojiTest());
        // gpui-kit (wave 6: styled input components)
        runner.add(new tests.kit.InputComponentsTest());
        runner.add(new tests.kit.ComponentInputTest());
        runner.add(new tests.kit.ComponentEditorTest());
        runner.add(new tests.kit.ComponentEditorCompletionsTest());
        runner.add(new tests.kit.ComponentEditorIntegrationTest());
        runner.add(new tests.kit.ComponentDiffParserTest());
        runner.add(new tests.kit.ComponentDiffDocumentTest());
        runner.add(new tests.kit.ComponentDiffStateTest());
        runner.add(new tests.kit.ComponentDiffReviewTest());
        runner.add(new tests.kit.ComponentDiffSelectionTest());
        runner.add(new tests.kit.ComponentDiffRenderTest());
        // gpui-kit (wave 6: list, select)
        runner.add(new tests.kit.ComponentListTest());
        runner.add(new tests.kit.BaseSelectTest());
        runner.add(new tests.kit.ComponentSelectTest());
        // gpui-kit (wave 6: searchable list, combobox, command palette)
        runner.add(new tests.kit.ComponentComboboxTest());
        runner.add(new tests.kit.ComponentCommandTest());
        runner.add(new tests.kit.ComponentSearchIntegrationTest());
        // gpui-kit (wave 6: form, setting, with the sidebar and resizable they use)
        runner.add(new tests.kit.ComponentFormTest());
        runner.add(new tests.kit.ComponentSettingTest());
        runner.add(new tests.kit.ComponentSidebarTest());
        // gpui-kit (wave 6: time, color picker)
        runner.add(new tests.kit.TimeComponentsTest());
        runner.add(new tests.kit.ColorPickerTest());
        // gpui-kit (wave 7: tabs)
        runner.add(new tests.kit.ComponentTabTest());
        // gpui-kit (wave 7: accordion, collapsible, pagination, stepper, title bar, window border)
        runner.add(new tests.kit.BaseDisclosureTest());
        runner.add(new tests.kit.ComponentDisclosureTest());
        runner.add(new tests.kit.BaseNavigationTest());
        runner.add(new tests.kit.ComponentNavigationTest());
        runner.add(new tests.kit.ComponentWindowTest());
        // gpui-kit (wave 7: base dock)
        runner.add(new tests.kit.BaseDockLayoutTest());
        runner.add(new tests.kit.BaseDockStateTest());
        runner.add(new tests.kit.BaseDockTest());
        runner.add(new tests.kit.BaseDockTabGroupTest());
        runner.add(new tests.kit.BaseDockAreaTest());
        // gpui-kit (wave 7: component dock)
        runner.add(new tests.kit.ComponentDockTest());
        runner.add(new tests.kit.ComponentDockIntegrationTest());
        // gpui-kit (wave 8: tree, table)
        runner.add(new tests.kit.BaseTreeTest());
        runner.add(new tests.kit.BaseTableTest());
        // gpui-kit (wave 9: plot, charts)
        runner.add(new tests.kit.PlotScaleTest());
        runner.add(new tests.kit.PlotBaseTest());
        runner.add(new tests.kit.PlotSankeyTest());
        runner.add(new tests.kit.ComponentChartTest());
        // gpui-kit (wave 10: rich text, view and interaction)
        runner.add(new tests.kit.BaseTextSelectionTest());
        runner.add(new tests.kit.TextSelectionTest());
        runner.add(new tests.kit.TextViewTest());
        runner.add(new tests.kit.ScrollRedrawTest());
        runner.add(new tests.kit.TextStreamFadeTest());
        runner.add(new tests.kit.TextRangeHighlightTest());
        runner.add(new tests.kit.TextEditorHostTest());
        runner.add(new tests.kit.TextViewStateTest());
        runner.add(new tests.kit.TextViewLayoutTest());
        // gpui-kit (wave 10: rich text)
        runner.add(new tests.kit.TextInlineTest());
        runner.add(new tests.kit.TextInlineObjectTest());
        runner.add(new tests.kit.TextInlineFlowTest());
        runner.add(new tests.kit.TextHtml5MinifyTest());
        runner.add(new tests.kit.TextFormatHtmlTest());
        runner.add(new tests.kit.TextDataUrlTest());
        runner.add(new tests.kit.TextUtilsTest());
        runner.add(new tests.kit.TextStyleTest());
        runner.add(new tests.kit.TextFormatMarkdownTest());
        runner.add(new tests.kit.TextNodeTest());
        runner.add(new tests.kit.TextNodeRenderTest());
        runner.add(new tests.kit.TextDocumentTest());
        runner.add(new tests.kit.TextInlineVirtualTest());
        runner.add(new tests.kit.TextComponentTest());
        runner.add(new tests.kit.TextWindowSelectionTest());
        // gpui-kit wave 10: chat components
        runner.add(new tests.kit.MessageTest());
        runner.add(new tests.kit.BubbleTest());
        runner.add(new tests.kit.MessageScrollerTest());
        runner.add(new tests.kit.AttachmentTest());
        // gpui-kit wave 12: carousel
        runner.add(new tests.kit.ComponentCarouselTest());
        runner.add(new tests.kit.ComponentInspectorTest());
        #if gpui_inspector
        runner.add(new tests.kit.InspectorStyleJsonTest());
        runner.add(new tests.kit.ComponentInspectorPanelTest());
        #end
        // gpui-kit wave 12: questionnaire
        runner.add(new tests.kit.BaseQuestionnaireTest());
        runner.add(new tests.kit.ComponentQuestionnaireTest());
        // gpui-kit wave 11: code highlighter
        runner.add(new tests.kit.HighlighterTest());
        // Deliberate deviations (DEVIATIONS.md)
        runner.add(new tests.kit.DeviationsTest());
        // The story gallery (samples/story/shared)
        runner.add(new tests.kit.StoryGalleryTest());
        runner.add(new tests.kit.StoryInputCompletionTest());
        runner.add(new tests.kit.StoryListTest());

    }

}
