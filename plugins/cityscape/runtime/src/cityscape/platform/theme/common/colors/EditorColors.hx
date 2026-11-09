// Ported from vscode src/vs/platform/theme/common/colors/editorColors.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common.colors;

import cityscape.base.common.Color;
import cityscape.base.common.Color.RGBA;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.BaseColors;
import cityscape.platform.theme.common.colors.MiscColors;

/**
 * The color ids of editorColors.ts (the constants of the module) and their
 * registration, run once when the color registry is built
 * (`ColorRegistry.registerAllColors`).
 */
class EditorColors {

    // ----- editor
    public static inline final editorBackground:ColorIdentifier = 'editor.background';
    public static inline final editorForeground:ColorIdentifier = 'editor.foreground';
    public static inline final editorStickyScrollBackground:ColorIdentifier = 'editorStickyScroll.background';
    public static inline final editorStickyScrollHoverBackground:ColorIdentifier = 'editorStickyScrollHover.background';
    public static inline final editorStickyScrollBorder:ColorIdentifier = 'editorStickyScroll.border';
    public static inline final editorStickyScrollShadow:ColorIdentifier = 'editorStickyScroll.shadow';
    public static inline final editorWidgetBackground:ColorIdentifier = 'editorWidget.background';
    public static inline final editorWidgetForeground:ColorIdentifier = 'editorWidget.foreground';
    public static inline final editorWidgetBorder:ColorIdentifier = 'editorWidget.border';
    public static inline final editorWidgetResizeBorder:ColorIdentifier = 'editorWidget.resizeBorder';
    public static inline final editorErrorBackground:ColorIdentifier = 'editorError.background';
    public static inline final editorErrorForeground:ColorIdentifier = 'editorError.foreground';
    public static inline final editorErrorBorder:ColorIdentifier = 'editorError.border';
    public static inline final editorWarningBackground:ColorIdentifier = 'editorWarning.background';
    public static inline final editorWarningForeground:ColorIdentifier = 'editorWarning.foreground';
    public static inline final editorWarningBorder:ColorIdentifier = 'editorWarning.border';
    public static inline final editorInfoBackground:ColorIdentifier = 'editorInfo.background';
    public static inline final editorInfoForeground:ColorIdentifier = 'editorInfo.foreground';
    public static inline final editorInfoBorder:ColorIdentifier = 'editorInfo.border';
    public static inline final editorHintForeground:ColorIdentifier = 'editorHint.foreground';
    public static inline final editorHintBorder:ColorIdentifier = 'editorHint.border';
    public static inline final editorActiveLinkForeground:ColorIdentifier = 'editorLink.activeForeground';
    // ----- editor selection
    public static inline final editorSelectionBackground:ColorIdentifier = 'editor.selectionBackground';
    public static inline final editorSelectionForeground:ColorIdentifier = 'editor.selectionForeground';
    public static inline final editorInactiveSelection:ColorIdentifier = 'editor.inactiveSelectionBackground';
    public static inline final editorSelectionHighlight:ColorIdentifier = 'editor.selectionHighlightBackground';
    public static inline final editorSelectionHighlightBorder:ColorIdentifier = 'editor.selectionHighlightBorder';
    // ----- editor find
    public static inline final editorFindMatch:ColorIdentifier = 'editor.findMatchBackground';
    public static inline final editorFindMatchForeground:ColorIdentifier = 'editor.findMatchForeground';
    public static inline final editorFindMatchHighlight:ColorIdentifier = 'editor.findMatchHighlightBackground';
    public static inline final editorFindMatchHighlightForeground:ColorIdentifier = 'editor.findMatchHighlightForeground';
    public static inline final editorFindRangeHighlight:ColorIdentifier = 'editor.findRangeHighlightBackground';
    public static inline final editorFindMatchBorder:ColorIdentifier = 'editor.findMatchBorder';
    public static inline final editorFindMatchHighlightBorder:ColorIdentifier = 'editor.findMatchHighlightBorder';
    public static inline final editorFindRangeHighlightBorder:ColorIdentifier = 'editor.findRangeHighlightBorder';
    // ----- editor hover
    public static inline final editorHoverHighlight:ColorIdentifier = 'editor.hoverHighlightBackground';
    public static inline final editorHoverBackground:ColorIdentifier = 'editorHoverWidget.background';
    public static inline final editorHoverForeground:ColorIdentifier = 'editorHoverWidget.foreground';
    public static inline final editorHoverBorder:ColorIdentifier = 'editorHoverWidget.border';
    public static inline final editorHoverStatusBarBackground:ColorIdentifier = 'editorHoverWidget.statusBarBackground';
    // ----- editor inlay hint
    public static inline final editorInlayHintForeground:ColorIdentifier = 'editorInlayHint.foreground';
    public static inline final editorInlayHintBackground:ColorIdentifier = 'editorInlayHint.background';
    public static inline final editorInlayHintTypeForeground:ColorIdentifier = 'editorInlayHint.typeForeground';
    public static inline final editorInlayHintTypeBackground:ColorIdentifier = 'editorInlayHint.typeBackground';
    public static inline final editorInlayHintParameterForeground:ColorIdentifier = 'editorInlayHint.parameterForeground';
    public static inline final editorInlayHintParameterBackground:ColorIdentifier = 'editorInlayHint.parameterBackground';
    // ----- editor lightbulb
    public static inline final editorLightBulbForeground:ColorIdentifier = 'editorLightBulb.foreground';
    public static inline final editorLightBulbAutoFixForeground:ColorIdentifier = 'editorLightBulbAutoFix.foreground';
    public static inline final editorLightBulbAiForeground:ColorIdentifier = 'editorLightBulbAi.foreground';
    // ----- editor snippet
    public static inline final snippetTabstopHighlightBackground:ColorIdentifier = 'editor.snippetTabstopHighlightBackground';
    public static inline final snippetTabstopHighlightBorder:ColorIdentifier = 'editor.snippetTabstopHighlightBorder';
    public static inline final snippetFinalTabstopHighlightBackground:ColorIdentifier = 'editor.snippetFinalTabstopHighlightBackground';
    public static inline final snippetFinalTabstopHighlightBorder:ColorIdentifier = 'editor.snippetFinalTabstopHighlightBorder';
    // ----- diff editor
    public static final defaultInsertColor = new Color(new RGBA(155, 185, 85, 0.2));
    public static final defaultRemoveColor = new Color(new RGBA(255, 0, 0, 0.2));
    public static inline final diffInserted:ColorIdentifier = 'diffEditor.insertedTextBackground';
    public static inline final diffRemoved:ColorIdentifier = 'diffEditor.removedTextBackground';
    public static inline final diffInsertedLine:ColorIdentifier = 'diffEditor.insertedLineBackground';
    public static inline final diffRemovedLine:ColorIdentifier = 'diffEditor.removedLineBackground';
    public static inline final diffInsertedLineGutter:ColorIdentifier = 'diffEditorGutter.insertedLineBackground';
    public static inline final diffRemovedLineGutter:ColorIdentifier = 'diffEditorGutter.removedLineBackground';
    public static inline final diffOverviewRulerInserted:ColorIdentifier = 'diffEditorOverview.insertedForeground';
    public static inline final diffOverviewRulerRemoved:ColorIdentifier = 'diffEditorOverview.removedForeground';
    public static inline final diffInsertedOutline:ColorIdentifier = 'diffEditor.insertedTextBorder';
    public static inline final diffRemovedOutline:ColorIdentifier = 'diffEditor.removedTextBorder';
    public static inline final diffBorder:ColorIdentifier = 'diffEditor.border';
    public static inline final diffDiagonalFill:ColorIdentifier = 'diffEditor.diagonalFill';
    public static inline final diffUnchangedRegionBackground:ColorIdentifier = 'diffEditor.unchangedRegionBackground';
    public static inline final diffUnchangedRegionForeground:ColorIdentifier = 'diffEditor.unchangedRegionForeground';
    public static inline final diffUnchangedTextBackground:ColorIdentifier = 'diffEditor.unchangedCodeBackground';
    // ----- widget
    public static inline final widgetShadow:ColorIdentifier = 'widget.shadow';
    public static inline final widgetBorder:ColorIdentifier = 'widget.border';
    // ----- toolbar
    public static inline final toolbarHoverBackground:ColorIdentifier = 'toolbar.hoverBackground';
    public static inline final toolbarHoverOutline:ColorIdentifier = 'toolbar.hoverOutline';
    public static inline final toolbarActiveBackground:ColorIdentifier = 'toolbar.activeBackground';
    // ----- breadcumbs
    public static inline final breadcrumbsForeground:ColorIdentifier = 'breadcrumb.foreground';
    public static inline final breadcrumbsBackground:ColorIdentifier = 'breadcrumb.background';
    public static inline final breadcrumbsFocusForeground:ColorIdentifier = 'breadcrumb.focusForeground';
    public static inline final breadcrumbsActiveSelectionForeground:ColorIdentifier = 'breadcrumb.activeSelectionForeground';
    public static inline final breadcrumbsPickerBackground:ColorIdentifier = 'breadcrumbPicker.background';
    public static inline final mergeCurrentHeaderBackground:ColorIdentifier = 'merge.currentHeaderBackground';
    public static inline final mergeCurrentContentBackground:ColorIdentifier = 'merge.currentContentBackground';
    public static inline final mergeIncomingHeaderBackground:ColorIdentifier = 'merge.incomingHeaderBackground';
    public static inline final mergeIncomingContentBackground:ColorIdentifier = 'merge.incomingContentBackground';
    public static inline final mergeCommonHeaderBackground:ColorIdentifier = 'merge.commonHeaderBackground';
    public static inline final mergeCommonContentBackground:ColorIdentifier = 'merge.commonContentBackground';
    public static inline final mergeBorder:ColorIdentifier = 'merge.border';
    public static inline final overviewRulerCurrentContentForeground:ColorIdentifier = 'editorOverviewRuler.currentContentForeground';
    public static inline final overviewRulerIncomingContentForeground:ColorIdentifier = 'editorOverviewRuler.incomingContentForeground';
    public static inline final overviewRulerCommonContentForeground:ColorIdentifier = 'editorOverviewRuler.commonContentForeground';
    public static inline final overviewRulerFindMatchForeground:ColorIdentifier = 'editorOverviewRuler.findMatchForeground';
    public static inline final overviewRulerSelectionHighlightForeground:ColorIdentifier = 'editorOverviewRuler.selectionHighlightForeground';
    // ----- problems
    public static inline final problemsErrorIconForeground:ColorIdentifier = 'problemsErrorIcon.foreground';
    public static inline final problemsWarningIconForeground:ColorIdentifier = 'problemsWarningIcon.foreground';
    public static inline final problemsInfoIconForeground:ColorIdentifier = 'problemsInfoIcon.foreground';

    @:allow(cityscape.platform.theme.common.ColorRegistry)
    static function registerColors():Void {

        // ----- editor
        ColorUtils.registerColor(editorBackground,
            { light: '#ffffff', dark: '#1E1E1E', hcDark: Color.black, hcLight: Color.white },
            'Editor background color.');

        ColorUtils.registerColor(editorForeground,
            { light: '#333333', dark: '#BBBBBB', hcDark: Color.white, hcLight: BaseColors.foreground },
            'Editor default foreground color.');

        ColorUtils.registerColor(editorStickyScrollBackground,
            editorBackground,
            'Background color of sticky scroll in the editor');

        ColorUtils.registerColor(editorStickyScrollHoverBackground,
            { dark: '#2A2D2E', light: '#F0F0F0', hcDark: null, hcLight: Color.fromHex('#0F4A85').transparent(0.1) },
            'Background color of sticky scroll on hover in the editor');

        ColorUtils.registerColor(editorStickyScrollBorder,
            { dark: null, light: null, hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Border color of sticky scroll in the editor');

        ColorUtils.registerColor(editorStickyScrollShadow,
            MiscColors.scrollbarShadow,
            ' Shadow color of sticky scroll in the editor');

        ColorUtils.registerColor(editorWidgetBackground,
            { dark: '#252526', light: '#F3F3F3', hcDark: '#0C141F', hcLight: Color.white },
            'Background color of editor widgets, such as find/replace.');

        ColorUtils.registerColor(editorWidgetForeground,
            BaseColors.foreground,
            'Foreground color of editor widgets, such as find/replace.');

        ColorUtils.registerColor(editorWidgetBorder,
            { dark: '#454545', light: '#C8C8C8', hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Border color of editor widgets. The color is only used if the widget chooses to have a border and if the color is not overridden by a widget.');

        ColorUtils.registerColor(editorWidgetResizeBorder,
            null,
            'Border color of the resize bar of editor widgets. The color is only used if the widget chooses to have a resize border and if the color is not overridden by a widget.');

        ColorUtils.registerColor(editorErrorBackground,
            null,
            'Background color of error text in the editor. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(editorErrorForeground,
            { dark: '#F14C4C', light: '#E51400', hcDark: '#F48771', hcLight: '#B5200D' },
            'Foreground color of error squigglies in the editor.');

        ColorUtils.registerColor(editorErrorBorder,
            { dark: null, light: null, hcDark: Color.fromHex('#E47777').transparent(0.8), hcLight: '#B5200D' },
            'If set, color of double underlines for errors in the editor.');

        ColorUtils.registerColor(editorWarningBackground,
            null,
            'Background color of warning text in the editor. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(editorWarningForeground,
            { dark: '#CCA700', light: '#BF8803', hcDark: '#FFD370', hcLight: '#895503' },
            'Foreground color of warning squigglies in the editor.');

        ColorUtils.registerColor(editorWarningBorder,
            { dark: null, light: null, hcDark: Color.fromHex('#FFCC00').transparent(0.8), hcLight: Color.fromHex('#FFCC00').transparent(0.8) },
            'If set, color of double underlines for warnings in the editor.');

        ColorUtils.registerColor(editorInfoBackground,
            null,
            'Background color of info text in the editor. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(editorInfoForeground,
            { dark: '#3794FF', light: '#1a85ff', hcDark: '#3794FF', hcLight: '#1a85ff' },
            'Foreground color of info squigglies in the editor.');

        ColorUtils.registerColor(editorInfoBorder,
            { dark: null, light: null, hcDark: Color.fromHex('#3794FF').transparent(0.8), hcLight: '#292929' },
            'If set, color of double underlines for infos in the editor.');

        ColorUtils.registerColor(editorHintForeground,
            { dark: Color.fromHex('#eeeeee').transparent(0.7), light: '#6c6c6c', hcDark: null, hcLight: null },
            'Foreground color of hint squigglies in the editor.');

        ColorUtils.registerColor(editorHintBorder,
            { dark: null, light: null, hcDark: Color.fromHex('#eeeeee').transparent(0.8), hcLight: '#292929' },
            'If set, color of double underlines for hints in the editor.');

        ColorUtils.registerColor(editorActiveLinkForeground,
            { dark: '#4E94CE', light: Color.blue, hcDark: Color.cyan, hcLight: '#292929' },
            'Color of active links.');

        // ----- editor selection
        ColorUtils.registerColor(editorSelectionBackground,
            { light: '#ADD6FF', dark: '#264F78', hcDark: '#f3f518', hcLight: '#0F4A85' },
            'Color of the editor selection.');

        ColorUtils.registerColor(editorSelectionForeground,
            { light: null, dark: null, hcDark: '#000000', hcLight: Color.white },
            'Color of the selected text for high contrast.');

        ColorUtils.registerColor(editorInactiveSelection,
            { light: ColorUtils.transparent(editorSelectionBackground, 0.5), dark: ColorUtils.transparent(editorSelectionBackground, 0.5), hcDark: ColorUtils.transparent(editorSelectionBackground, 0.7), hcLight: ColorUtils.transparent(editorSelectionBackground, 0.5) },
            'Color of the selection in an inactive editor. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(editorSelectionHighlight,
            { light: ColorUtils.lessProminent(editorSelectionBackground, editorBackground, 0.3, 0.6), dark: ColorUtils.lessProminent(editorSelectionBackground, editorBackground, 0.3, 0.6), hcDark: null, hcLight: null },
            'Color for regions with the same content as the selection. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(editorSelectionHighlightBorder,
            { light: null, dark: null, hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder },
            'Border color for regions with the same content as the selection.');

        // ----- editor find
        ColorUtils.registerColor(editorFindMatch,
            { light: '#A8AC94', dark: '#515C6A', hcDark: null, hcLight: null },
            'Color of the current search match.');

        ColorUtils.registerColor(editorFindMatchForeground,
            null,
            'Text color of the current search match.');

        ColorUtils.registerColor(editorFindMatchHighlight,
            { light: '#EA5C0055', dark: '#EA5C0055', hcDark: null, hcLight: null },
            'Color of the other search matches. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(editorFindMatchHighlightForeground,
            null,
            'Foreground color of the other search matches.',
            true);

        ColorUtils.registerColor(editorFindRangeHighlight,
            { dark: '#3a3d4166', light: '#b4b4b44d', hcDark: null, hcLight: null },
            'Color of the range limiting the search. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(editorFindMatchBorder,
            { light: null, dark: null, hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder },
            'Border color of the current search match.');

        ColorUtils.registerColor(editorFindMatchHighlightBorder,
            { light: null, dark: null, hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder },
            'Border color of the other search matches.');

        ColorUtils.registerColor(editorFindRangeHighlightBorder,
            { dark: null, light: null, hcDark: ColorUtils.transparent(BaseColors.activeContrastBorder, 0.4), hcLight: ColorUtils.transparent(BaseColors.activeContrastBorder, 0.4) },
            'Border color of the range limiting the search. The color must not be opaque so as not to hide underlying decorations.',
            true);

        // ----- editor hover
        ColorUtils.registerColor(editorHoverHighlight,
            { light: '#ADD6FF26', dark: '#264f7840', hcDark: '#ADD6FF26', hcLight: null },
            'Highlight below the word for which a hover is shown. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(editorHoverBackground,
            editorWidgetBackground,
            'Background color of the editor hover.');

        ColorUtils.registerColor(editorHoverForeground,
            editorWidgetForeground,
            'Foreground color of the editor hover.');

        ColorUtils.registerColor(editorHoverBorder,
            editorWidgetBorder,
            'Border color of the editor hover.');

        ColorUtils.registerColor(editorHoverStatusBarBackground,
            { dark: ColorUtils.lighten(editorHoverBackground, 0.2), light: ColorUtils.darken(editorHoverBackground, 0.05), hcDark: editorWidgetBackground, hcLight: editorWidgetBackground },
            'Background color of the editor hover status bar.');

        // ----- editor inlay hint
        ColorUtils.registerColor(editorInlayHintForeground,
            { dark: '#969696', light: '#969696', hcDark: Color.white, hcLight: Color.black },
            'Foreground color of inline hints');

        ColorUtils.registerColor(editorInlayHintBackground,
            { dark: ColorUtils.transparent(MiscColors.badgeBackground, 0.1), light: ColorUtils.transparent(MiscColors.badgeBackground, 0.1), hcDark: ColorUtils.transparent(Color.white, 0.1), hcLight: ColorUtils.transparent(MiscColors.badgeBackground, 0.1) },
            'Background color of inline hints');

        ColorUtils.registerColor(editorInlayHintTypeForeground,
            editorInlayHintForeground,
            'Foreground color of inline hints for types');

        ColorUtils.registerColor(editorInlayHintTypeBackground,
            editorInlayHintBackground,
            'Background color of inline hints for types');

        ColorUtils.registerColor(editorInlayHintParameterForeground,
            editorInlayHintForeground,
            'Foreground color of inline hints for parameters');

        ColorUtils.registerColor(editorInlayHintParameterBackground,
            editorInlayHintBackground,
            'Background color of inline hints for parameters');

        // ----- editor lightbulb
        ColorUtils.registerColor(editorLightBulbForeground,
            { dark: '#FFCC00', light: '#DDB100', hcDark: '#FFCC00', hcLight: '#007ACC' },
            'The color used for the lightbulb actions icon.');

        ColorUtils.registerColor(editorLightBulbAutoFixForeground,
            { dark: '#75BEFF', light: '#007ACC', hcDark: '#75BEFF', hcLight: '#007ACC' },
            'The color used for the lightbulb auto fix actions icon.');

        ColorUtils.registerColor(editorLightBulbAiForeground,
            editorLightBulbForeground,
            'The color used for the lightbulb AI icon.');

        // ----- editor snippet
        ColorUtils.registerColor(snippetTabstopHighlightBackground,
            { dark: new Color(new RGBA(124, 124, 124, 0.3)), light: new Color(new RGBA(10, 50, 100, 0.2)), hcDark: new Color(new RGBA(124, 124, 124, 0.3)), hcLight: new Color(new RGBA(10, 50, 100, 0.2)) },
            'Highlight background color of a snippet tabstop.');

        ColorUtils.registerColor(snippetTabstopHighlightBorder,
            null,
            'Highlight border color of a snippet tabstop.');

        ColorUtils.registerColor(snippetFinalTabstopHighlightBackground,
            null,
            'Highlight background color of the final tabstop of a snippet.');

        ColorUtils.registerColor(snippetFinalTabstopHighlightBorder,
            { dark: '#525252', light: new Color(new RGBA(10, 50, 100, 0.5)), hcDark: '#525252', hcLight: '#292929' },
            'Highlight border color of the final tabstop of a snippet.');

        ColorUtils.registerColor(diffInserted,
            { dark: '#9ccc2c33', light: '#9ccc2c40', hcDark: null, hcLight: null },
            'Background color for text that got inserted. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(diffRemoved,
            { dark: '#ff000033', light: '#ff000033', hcDark: null, hcLight: null },
            'Background color for text that got removed. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(diffInsertedLine,
            { dark: defaultInsertColor, light: defaultInsertColor, hcDark: null, hcLight: null },
            'Background color for lines that got inserted. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(diffRemovedLine,
            { dark: defaultRemoveColor, light: defaultRemoveColor, hcDark: null, hcLight: null },
            'Background color for lines that got removed. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(diffInsertedLineGutter,
            null,
            'Background color for the margin where lines got inserted.');

        ColorUtils.registerColor(diffRemovedLineGutter,
            null,
            'Background color for the margin where lines got removed.');

        ColorUtils.registerColor(diffOverviewRulerInserted,
            null,
            'Diff overview ruler foreground for inserted content.');

        ColorUtils.registerColor(diffOverviewRulerRemoved,
            null,
            'Diff overview ruler foreground for removed content.');

        ColorUtils.registerColor(diffInsertedOutline,
            { dark: null, light: null, hcDark: '#33ff2eff', hcLight: '#374E06' },
            'Outline color for the text that got inserted.');

        ColorUtils.registerColor(diffRemovedOutline,
            { dark: null, light: null, hcDark: '#FF008F', hcLight: '#AD0707' },
            'Outline color for text that got removed.');

        ColorUtils.registerColor(diffBorder,
            { dark: null, light: null, hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Border color between the two text editors.');

        ColorUtils.registerColor(diffDiagonalFill,
            { dark: '#cccccc33', light: '#22222233', hcDark: null, hcLight: null },
            'Color of the diff editor\'s diagonal fill. The diagonal fill is used in side-by-side diff views.');

        ColorUtils.registerColor(diffUnchangedRegionBackground,
            'sideBar.background',
            'The background color of unchanged blocks in the diff editor.');

        ColorUtils.registerColor(diffUnchangedRegionForeground,
            'foreground',
            'The foreground color of unchanged blocks in the diff editor.');

        ColorUtils.registerColor(diffUnchangedTextBackground,
            { dark: '#74747429', light: '#b8b8b829', hcDark: null, hcLight: null },
            'The background color of unchanged code in the diff editor.');

        // ----- widget
        ColorUtils.registerColor(widgetShadow,
            { dark: ColorUtils.transparent(Color.black, 0.36), light: ColorUtils.transparent(Color.black, 0.16), hcDark: null, hcLight: null },
            'Shadow color of widgets such as find/replace inside the editor.');

        ColorUtils.registerColor(widgetBorder,
            { dark: null, light: null, hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Border color of widgets such as find/replace inside the editor.');

        // ----- toolbar
        ColorUtils.registerColor(toolbarHoverBackground,
            { dark: '#5a5d5e50', light: '#b8b8b850', hcDark: null, hcLight: null },
            'Toolbar background when hovering over actions using the mouse');

        ColorUtils.registerColor(toolbarHoverOutline,
            { dark: null, light: null, hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder },
            'Toolbar outline when hovering over actions using the mouse');

        ColorUtils.registerColor(toolbarActiveBackground,
            { dark: ColorUtils.lighten(toolbarHoverBackground, 0.1), light: ColorUtils.darken(toolbarHoverBackground, 0.1), hcDark: null, hcLight: null },
            'Toolbar background when holding the mouse over actions');

        // ----- breadcumbs
        ColorUtils.registerColor(breadcrumbsForeground,
            ColorUtils.transparent(BaseColors.foreground, 0.8),
            'Color of focused breadcrumb items.');

        ColorUtils.registerColor(breadcrumbsBackground,
            editorBackground,
            'Background color of breadcrumb items.');

        ColorUtils.registerColor(breadcrumbsFocusForeground,
            { light: ColorUtils.darken(BaseColors.foreground, 0.2), dark: ColorUtils.lighten(BaseColors.foreground, 0.1), hcDark: ColorUtils.lighten(BaseColors.foreground, 0.1), hcLight: ColorUtils.lighten(BaseColors.foreground, 0.1) },
            'Color of focused breadcrumb items.');

        ColorUtils.registerColor(breadcrumbsActiveSelectionForeground,
            { light: ColorUtils.darken(BaseColors.foreground, 0.2), dark: ColorUtils.lighten(BaseColors.foreground, 0.1), hcDark: ColorUtils.lighten(BaseColors.foreground, 0.1), hcLight: ColorUtils.lighten(BaseColors.foreground, 0.1) },
            'Color of selected breadcrumb items.');

        ColorUtils.registerColor(breadcrumbsPickerBackground,
            editorWidgetBackground,
            'Background color of breadcrumb item picker.');

        // ----- merge
        final headerTransparency = 0.5;

        final currentBaseColor = Color.fromHex('#40C8AE').transparent(headerTransparency);

        final incomingBaseColor = Color.fromHex('#40A6FF').transparent(headerTransparency);

        final commonBaseColor = Color.fromHex('#606060').transparent(0.4);

        final contentTransparency = 0.4;

        final rulerTransparency = 1;

        ColorUtils.registerColor(mergeCurrentHeaderBackground,
            { dark: currentBaseColor, light: currentBaseColor, hcDark: null, hcLight: null },
            'Current header background in inline merge-conflicts. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(mergeCurrentContentBackground,
            ColorUtils.transparent(mergeCurrentHeaderBackground, contentTransparency),
            'Current content background in inline merge-conflicts. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(mergeIncomingHeaderBackground,
            { dark: incomingBaseColor, light: incomingBaseColor, hcDark: null, hcLight: null },
            'Incoming header background in inline merge-conflicts. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(mergeIncomingContentBackground,
            ColorUtils.transparent(mergeIncomingHeaderBackground, contentTransparency),
            'Incoming content background in inline merge-conflicts. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(mergeCommonHeaderBackground,
            { dark: commonBaseColor, light: commonBaseColor, hcDark: null, hcLight: null },
            'Common ancestor header background in inline merge-conflicts. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(mergeCommonContentBackground,
            ColorUtils.transparent(mergeCommonHeaderBackground, contentTransparency),
            'Common ancestor content background in inline merge-conflicts. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(mergeBorder,
            { dark: null, light: null, hcDark: '#C3DF6F', hcLight: '#007ACC' },
            'Border color on headers and the splitter in inline merge-conflicts.');

        ColorUtils.registerColor(overviewRulerCurrentContentForeground,
            { dark: ColorUtils.transparent(mergeCurrentHeaderBackground, rulerTransparency), light: ColorUtils.transparent(mergeCurrentHeaderBackground, rulerTransparency), hcDark: mergeBorder, hcLight: mergeBorder },
            'Current overview ruler foreground for inline merge-conflicts.');

        ColorUtils.registerColor(overviewRulerIncomingContentForeground,
            { dark: ColorUtils.transparent(mergeIncomingHeaderBackground, rulerTransparency), light: ColorUtils.transparent(mergeIncomingHeaderBackground, rulerTransparency), hcDark: mergeBorder, hcLight: mergeBorder },
            'Incoming overview ruler foreground for inline merge-conflicts.');

        ColorUtils.registerColor(overviewRulerCommonContentForeground,
            { dark: ColorUtils.transparent(mergeCommonHeaderBackground, rulerTransparency), light: ColorUtils.transparent(mergeCommonHeaderBackground, rulerTransparency), hcDark: mergeBorder, hcLight: mergeBorder },
            'Common ancestor overview ruler foreground for inline merge-conflicts.');

        ColorUtils.registerColor(overviewRulerFindMatchForeground,
            { dark: '#d186167e', light: '#d186167e', hcDark: '#AB5A00', hcLight: '#AB5A00' },
            'Overview ruler marker color for find matches. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(overviewRulerSelectionHighlightForeground,
            '#A0A0A0CC',
            'Overview ruler marker color for selection highlights. The color must not be opaque so as not to hide underlying decorations.',
            true);

        // ----- problems
        ColorUtils.registerColor(problemsErrorIconForeground,
            editorErrorForeground,
            'The color used for the problems error icon.');

        ColorUtils.registerColor(problemsWarningIconForeground,
            editorWarningForeground,
            'The color used for the problems warning icon.');

        ColorUtils.registerColor(problemsInfoIconForeground,
            editorInfoForeground,
            'The color used for the problems info icon.');

    }

}
