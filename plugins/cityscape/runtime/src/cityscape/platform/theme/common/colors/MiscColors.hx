// Ported from vscode src/vs/platform/theme/common/colors/miscColors.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common.colors;

import cityscape.base.common.Color;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.BaseColors;

/**
 * The color ids of miscColors.ts (the constants of the module) and their
 * registration, run once when the color registry is built
 * (`ColorRegistry.registerAllColors`).
 */
class MiscColors {

    // ----- sash
    public static inline final sashHoverBorder:ColorIdentifier = 'sash.hoverBorder';
    // ----- badge
    public static inline final badgeBackground:ColorIdentifier = 'badge.background';
    public static inline final badgeForeground:ColorIdentifier = 'badge.foreground';
    // ----- scrollbar
    public static inline final scrollbarShadow:ColorIdentifier = 'scrollbar.shadow';
    public static inline final scrollbarSliderBackground:ColorIdentifier = 'scrollbarSlider.background';
    public static inline final scrollbarSliderHoverBackground:ColorIdentifier = 'scrollbarSlider.hoverBackground';
    public static inline final scrollbarSliderActiveBackground:ColorIdentifier = 'scrollbarSlider.activeBackground';
    // ----- progress bar
    public static inline final progressBarBackground:ColorIdentifier = 'progressBar.background';

    @:allow(cityscape.platform.theme.common.ColorRegistry)
    static function registerColors():Void {

        // ----- sash
        ColorUtils.registerColor(sashHoverBorder,
            BaseColors.focusBorder,
            'Border color of active sashes.');

        // ----- badge
        ColorUtils.registerColor(badgeBackground,
            { dark: '#4D4D4D', light: '#C4C4C4', hcDark: Color.black, hcLight: '#0F4A85' },
            'Badge background color. Badges are small information labels, e.g. for search results count.');

        ColorUtils.registerColor(badgeForeground,
            { dark: Color.white, light: '#333', hcDark: Color.white, hcLight: Color.white },
            'Badge foreground color. Badges are small information labels, e.g. for search results count.');

        // ----- scrollbar
        ColorUtils.registerColor(scrollbarShadow,
            { dark: '#000000', light: '#DDDDDD', hcDark: null, hcLight: null },
            'Scrollbar shadow to indicate that the view is scrolled.');

        ColorUtils.registerColor(scrollbarSliderBackground,
            { dark: Color.fromHex('#797979').transparent(0.4), light: Color.fromHex('#646464').transparent(0.4), hcDark: ColorUtils.transparent(BaseColors.contrastBorder, 0.6), hcLight: ColorUtils.transparent(BaseColors.contrastBorder, 0.4) },
            'Scrollbar slider background color.');

        ColorUtils.registerColor(scrollbarSliderHoverBackground,
            { dark: Color.fromHex('#646464').transparent(0.7), light: Color.fromHex('#646464').transparent(0.7), hcDark: ColorUtils.transparent(BaseColors.contrastBorder, 0.8), hcLight: ColorUtils.transparent(BaseColors.contrastBorder, 0.8) },
            'Scrollbar slider background color when hovering.');

        ColorUtils.registerColor(scrollbarSliderActiveBackground,
            { dark: Color.fromHex('#BFBFBF').transparent(0.4), light: Color.fromHex('#000000').transparent(0.6), hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Scrollbar slider background color when clicked on.');

        // ----- progress bar
        ColorUtils.registerColor(progressBarBackground,
            { dark: Color.fromHex('#0E70C0'), light: Color.fromHex('#0E70C0'), hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Background color of the progress bar that can show for long running operations.');

    }

}
