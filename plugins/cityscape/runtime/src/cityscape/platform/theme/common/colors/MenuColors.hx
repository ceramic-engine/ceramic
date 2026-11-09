// Ported from vscode src/vs/platform/theme/common/colors/menuColors.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common.colors;

import cityscape.base.common.Color;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.BaseColors;
import cityscape.platform.theme.common.colors.InputColors;
import cityscape.platform.theme.common.colors.ListColors;

/**
 * The color ids of menuColors.ts (the constants of the module) and their
 * registration, run once when the color registry is built
 * (`ColorRegistry.registerAllColors`).
 */
class MenuColors {

    public static inline final menuBorder:ColorIdentifier = 'menu.border';
    public static inline final menuForeground:ColorIdentifier = 'menu.foreground';
    public static inline final menuBackground:ColorIdentifier = 'menu.background';
    public static inline final menuSelectionForeground:ColorIdentifier = 'menu.selectionForeground';
    public static inline final menuSelectionBackground:ColorIdentifier = 'menu.selectionBackground';
    public static inline final menuSelectionBorder:ColorIdentifier = 'menu.selectionBorder';
    public static inline final menuSeparatorBackground:ColorIdentifier = 'menu.separatorBackground';

    @:allow(cityscape.platform.theme.common.ColorRegistry)
    static function registerColors():Void {

        ColorUtils.registerColor(menuBorder,
            { dark: null, light: null, hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Border color of menus.');

        ColorUtils.registerColor(menuForeground,
            InputColors.selectForeground,
            'Foreground color of menu items.');

        ColorUtils.registerColor(menuBackground,
            InputColors.selectBackground,
            'Background color of menu items.');

        ColorUtils.registerColor(menuSelectionForeground,
            ListColors.listActiveSelectionForeground,
            'Foreground color of the selected menu item in menus.');

        ColorUtils.registerColor(menuSelectionBackground,
            ListColors.listActiveSelectionBackground,
            'Background color of the selected menu item in menus.');

        ColorUtils.registerColor(menuSelectionBorder,
            { dark: null, light: null, hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder },
            'Border color of the selected menu item in menus.');

        ColorUtils.registerColor(menuSeparatorBackground,
            { dark: '#606060', light: '#D4D4D4', hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Color of a separator menu item in menus.');

    }

}
