// Ported from vscode src/vs/platform/theme/common/colors/quickpickColors.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common.colors;

import cityscape.base.common.Color;
import cityscape.base.common.Color.RGBA;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.EditorColors;
import cityscape.platform.theme.common.colors.ListColors;

/**
 * The color ids of quickpickColors.ts (the constants of the module) and their
 * registration, run once when the color registry is built
 * (`ColorRegistry.registerAllColors`).
 */
class QuickpickColors {

    public static inline final quickInputBackground:ColorIdentifier = 'quickInput.background';
    public static inline final quickInputForeground:ColorIdentifier = 'quickInput.foreground';
    public static inline final quickInputTitleBackground:ColorIdentifier = 'quickInputTitle.background';
    public static inline final pickerGroupForeground:ColorIdentifier = 'pickerGroup.foreground';
    public static inline final pickerGroupBorder:ColorIdentifier = 'pickerGroup.border';
    public static inline final _deprecatedQuickInputListFocusBackground:ColorIdentifier = 'quickInput.list.focusBackground';
    public static inline final quickInputListFocusForeground:ColorIdentifier = 'quickInputList.focusForeground';
    public static inline final quickInputListFocusIconForeground:ColorIdentifier = 'quickInputList.focusIconForeground';
    public static inline final quickInputListFocusBackground:ColorIdentifier = 'quickInputList.focusBackground';

    @:allow(cityscape.platform.theme.common.ColorRegistry)
    static function registerColors():Void {

        ColorUtils.registerColor(quickInputBackground,
            EditorColors.editorWidgetBackground,
            'Quick picker background color. The quick picker widget is the container for pickers like the command palette.');

        ColorUtils.registerColor(quickInputForeground,
            EditorColors.editorWidgetForeground,
            'Quick picker foreground color. The quick picker widget is the container for pickers like the command palette.');

        ColorUtils.registerColor(quickInputTitleBackground,
            { dark: new Color(new RGBA(255, 255, 255, 0.105)), light: new Color(new RGBA(0, 0, 0, 0.06)), hcDark: '#000000', hcLight: Color.white },
            'Quick picker title background color. The quick picker widget is the container for pickers like the command palette.');

        ColorUtils.registerColor(pickerGroupForeground,
            { dark: '#3794FF', light: '#0066BF', hcDark: Color.white, hcLight: '#0F4A85' },
            'Quick picker color for grouping labels.');

        ColorUtils.registerColor(pickerGroupBorder,
            { dark: '#3F3F46', light: '#CCCEDB', hcDark: Color.white, hcLight: '#0F4A85' },
            'Quick picker color for grouping borders.');

        ColorUtils.registerColor(_deprecatedQuickInputListFocusBackground,
            null,
            '',
            false,
            'Please use quickInputList.focusBackground instead');

        ColorUtils.registerColor(quickInputListFocusForeground,
            ListColors.listActiveSelectionForeground,
            'Quick picker foreground color for the focused item.');

        ColorUtils.registerColor(quickInputListFocusIconForeground,
            ListColors.listActiveSelectionIconForeground,
            'Quick picker icon foreground color for the focused item.');

        ColorUtils.registerColor(quickInputListFocusBackground,
            { dark: ColorUtils.oneOf(_deprecatedQuickInputListFocusBackground, ListColors.listActiveSelectionBackground), light: ColorUtils.oneOf(_deprecatedQuickInputListFocusBackground, ListColors.listActiveSelectionBackground), hcDark: null, hcLight: null },
            'Quick picker background color for the focused item.');

    }

}
