// Ported from vscode src/vs/platform/theme/common/colors/listColors.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common.colors;

import cityscape.base.common.Color;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.BaseColors;
import cityscape.platform.theme.common.colors.EditorColors;

/**
 * The color ids of listColors.ts (the constants of the module) and their
 * registration, run once when the color registry is built
 * (`ColorRegistry.registerAllColors`).
 */
class ListColors {

    public static inline final listFocusBackground:ColorIdentifier = 'list.focusBackground';
    public static inline final listFocusForeground:ColorIdentifier = 'list.focusForeground';
    public static inline final listFocusOutline:ColorIdentifier = 'list.focusOutline';
    public static inline final listFocusAndSelectionOutline:ColorIdentifier = 'list.focusAndSelectionOutline';
    public static inline final listActiveSelectionBackground:ColorIdentifier = 'list.activeSelectionBackground';
    public static inline final listActiveSelectionForeground:ColorIdentifier = 'list.activeSelectionForeground';
    public static inline final listActiveSelectionIconForeground:ColorIdentifier = 'list.activeSelectionIconForeground';
    public static inline final listInactiveSelectionBackground:ColorIdentifier = 'list.inactiveSelectionBackground';
    public static inline final listInactiveSelectionForeground:ColorIdentifier = 'list.inactiveSelectionForeground';
    public static inline final listInactiveSelectionIconForeground:ColorIdentifier = 'list.inactiveSelectionIconForeground';
    public static inline final listInactiveFocusBackground:ColorIdentifier = 'list.inactiveFocusBackground';
    public static inline final listInactiveFocusOutline:ColorIdentifier = 'list.inactiveFocusOutline';
    public static inline final listHoverBackground:ColorIdentifier = 'list.hoverBackground';
    public static inline final listHoverForeground:ColorIdentifier = 'list.hoverForeground';
    public static inline final listDropOverBackground:ColorIdentifier = 'list.dropBackground';
    public static inline final listDropBetweenBackground:ColorIdentifier = 'list.dropBetweenBackground';
    public static inline final listHighlightForeground:ColorIdentifier = 'list.highlightForeground';
    public static inline final listFocusHighlightForeground:ColorIdentifier = 'list.focusHighlightForeground';
    public static inline final listInvalidItemForeground:ColorIdentifier = 'list.invalidItemForeground';
    public static inline final listErrorForeground:ColorIdentifier = 'list.errorForeground';
    public static inline final listWarningForeground:ColorIdentifier = 'list.warningForeground';
    public static inline final listFilterWidgetBackground:ColorIdentifier = 'listFilterWidget.background';
    public static inline final listFilterWidgetOutline:ColorIdentifier = 'listFilterWidget.outline';
    public static inline final listFilterWidgetNoMatchesOutline:ColorIdentifier = 'listFilterWidget.noMatchesOutline';
    public static inline final listFilterWidgetShadow:ColorIdentifier = 'listFilterWidget.shadow';
    public static inline final listFilterMatchHighlight:ColorIdentifier = 'list.filterMatchBackground';
    public static inline final listFilterMatchHighlightBorder:ColorIdentifier = 'list.filterMatchBorder';
    public static inline final listDeemphasizedForeground:ColorIdentifier = 'list.deemphasizedForeground';
    // ------ tree
    public static inline final treeIndentGuidesStroke:ColorIdentifier = 'tree.indentGuidesStroke';
    public static inline final treeInactiveIndentGuidesStroke:ColorIdentifier = 'tree.inactiveIndentGuidesStroke';
    // ------ table
    public static inline final tableColumnsBorder:ColorIdentifier = 'tree.tableColumnsBorder';
    public static inline final tableOddRowsBackgroundColor:ColorIdentifier = 'tree.tableOddRowsBackground';
    // ------ action list
    public static inline final editorActionListBackground:ColorIdentifier = 'editorActionList.background';
    public static inline final editorActionListForeground:ColorIdentifier = 'editorActionList.foreground';
    public static inline final editorActionListFocusForeground:ColorIdentifier = 'editorActionList.focusForeground';
    public static inline final editorActionListFocusBackground:ColorIdentifier = 'editorActionList.focusBackground';

    @:allow(cityscape.platform.theme.common.ColorRegistry)
    static function registerColors():Void {

        ColorUtils.registerColor(listFocusBackground,
            null,
            'List/Tree background color for the focused item when the list/tree is active. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listFocusForeground,
            null,
            'List/Tree foreground color for the focused item when the list/tree is active. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listFocusOutline,
            { dark: BaseColors.focusBorder, light: BaseColors.focusBorder, hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder },
            'List/Tree outline color for the focused item when the list/tree is active. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listFocusAndSelectionOutline,
            null,
            'List/Tree outline color for the focused item when the list/tree is active and selected. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listActiveSelectionBackground,
            { dark: '#04395E', light: '#0060C0', hcDark: null, hcLight: Color.fromHex('#0F4A85').transparent(0.1) },
            'List/Tree background color for the selected item when the list/tree is active. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listActiveSelectionForeground,
            { dark: Color.white, light: Color.white, hcDark: null, hcLight: null },
            'List/Tree foreground color for the selected item when the list/tree is active. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listActiveSelectionIconForeground,
            null,
            'List/Tree icon foreground color for the selected item when the list/tree is active. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listInactiveSelectionBackground,
            { dark: '#37373D', light: '#E4E6F1', hcDark: null, hcLight: Color.fromHex('#0F4A85').transparent(0.1) },
            'List/Tree background color for the selected item when the list/tree is inactive. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listInactiveSelectionForeground,
            null,
            'List/Tree foreground color for the selected item when the list/tree is inactive. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listInactiveSelectionIconForeground,
            null,
            'List/Tree icon foreground color for the selected item when the list/tree is inactive. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listInactiveFocusBackground,
            null,
            'List/Tree background color for the focused item when the list/tree is inactive. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listInactiveFocusOutline,
            null,
            'List/Tree outline color for the focused item when the list/tree is inactive. An active list/tree has keyboard focus, an inactive does not.');

        ColorUtils.registerColor(listHoverBackground,
            { dark: '#2A2D2E', light: '#F0F0F0', hcDark: Color.white.transparent(0.1), hcLight: Color.fromHex('#0F4A85').transparent(0.1) },
            'List/Tree background when hovering over items using the mouse.');

        ColorUtils.registerColor(listHoverForeground,
            null,
            'List/Tree foreground when hovering over items using the mouse.');

        ColorUtils.registerColor(listDropOverBackground,
            { dark: '#062F4A', light: '#D6EBFF', hcDark: null, hcLight: null },
            'List/Tree drag and drop background when moving items over other items when using the mouse.');

        ColorUtils.registerColor(listDropBetweenBackground,
            { dark: BaseColors.iconForeground, light: BaseColors.iconForeground, hcDark: null, hcLight: null },
            'List/Tree drag and drop border color when moving items between items when using the mouse.');

        ColorUtils.registerColor(listHighlightForeground,
            { dark: '#2AAAFF', light: '#0066BF', hcDark: BaseColors.focusBorder, hcLight: BaseColors.focusBorder },
            'List/Tree foreground color of the match highlights when searching inside the list/tree.');

        ColorUtils.registerColor(listFocusHighlightForeground,
            { dark: listHighlightForeground, light: ColorUtils.ifDefinedThenElse(listActiveSelectionBackground, listHighlightForeground, '#BBE7FF'), hcDark: listHighlightForeground, hcLight: listHighlightForeground },
            'List/Tree foreground color of the match highlights on actively focused items when searching inside the list/tree.');

        ColorUtils.registerColor(listInvalidItemForeground,
            { dark: '#B89500', light: '#B89500', hcDark: '#B89500', hcLight: '#B5200D' },
            'List/Tree foreground color for invalid items, for example an unresolved root in explorer.');

        ColorUtils.registerColor(listErrorForeground,
            { dark: '#F88070', light: '#B01011', hcDark: null, hcLight: null },
            'Foreground color of list items containing errors.');

        ColorUtils.registerColor(listWarningForeground,
            { dark: '#CCA700', light: '#855F00', hcDark: null, hcLight: null },
            'Foreground color of list items containing warnings.');

        ColorUtils.registerColor(listFilterWidgetBackground,
            { light: ColorUtils.darken(EditorColors.editorWidgetBackground, 0), dark: ColorUtils.lighten(EditorColors.editorWidgetBackground, 0), hcDark: EditorColors.editorWidgetBackground, hcLight: EditorColors.editorWidgetBackground },
            'Background color of the type filter widget in lists and trees.');

        ColorUtils.registerColor(listFilterWidgetOutline,
            { dark: Color.transparentStatic, light: Color.transparentStatic, hcDark: '#f38518', hcLight: '#007ACC' },
            'Outline color of the type filter widget in lists and trees.');

        ColorUtils.registerColor(listFilterWidgetNoMatchesOutline,
            { dark: '#BE1100', light: '#BE1100', hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Outline color of the type filter widget in lists and trees, when there are no matches.');

        ColorUtils.registerColor(listFilterWidgetShadow,
            EditorColors.widgetShadow,
            'Shadow color of the type filter widget in lists and trees.');

        ColorUtils.registerColor(listFilterMatchHighlight,
            { dark: EditorColors.editorFindMatchHighlight, light: EditorColors.editorFindMatchHighlight, hcDark: null, hcLight: null },
            'Background color of the filtered match.');

        ColorUtils.registerColor(listFilterMatchHighlightBorder,
            { dark: EditorColors.editorFindMatchHighlightBorder, light: EditorColors.editorFindMatchHighlightBorder, hcDark: BaseColors.contrastBorder, hcLight: BaseColors.activeContrastBorder },
            'Border color of the filtered match.');

        ColorUtils.registerColor(listDeemphasizedForeground,
            { dark: '#8C8C8C', light: '#8E8E90', hcDark: '#A7A8A9', hcLight: '#666666' },
            'List/Tree foreground color for items that are deemphasized.');

        // ------ tree
        ColorUtils.registerColor(treeIndentGuidesStroke,
            { dark: '#585858', light: '#a9a9a9', hcDark: '#a9a9a9', hcLight: '#a5a5a5' },
            'Tree stroke color for the indentation guides.');

        ColorUtils.registerColor(treeInactiveIndentGuidesStroke,
            ColorUtils.transparent(treeIndentGuidesStroke, 0.4),
            'Tree stroke color for the indentation guides that are not active.');

        // ------ table
        ColorUtils.registerColor(tableColumnsBorder,
            { dark: '#CCCCCC20', light: '#61616120', hcDark: null, hcLight: null },
            'Table border color between columns.');

        ColorUtils.registerColor(tableOddRowsBackgroundColor,
            { dark: ColorUtils.transparent(BaseColors.foreground, 0.04), light: ColorUtils.transparent(BaseColors.foreground, 0.04), hcDark: null, hcLight: null },
            'Background color for odd table rows.');

        // ------ action list
        ColorUtils.registerColor(editorActionListBackground,
            EditorColors.editorWidgetBackground,
            'Action List background color.');

        ColorUtils.registerColor(editorActionListForeground,
            EditorColors.editorWidgetForeground,
            'Action List foreground color.');

        ColorUtils.registerColor(editorActionListFocusForeground,
            listActiveSelectionForeground,
            'Action List foreground color for the focused item.');

        ColorUtils.registerColor(editorActionListFocusBackground,
            listActiveSelectionBackground,
            'Action List background color for the focused item.');

    }

}
