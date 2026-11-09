// Ported from vscode src/vs/platform/theme/common/colors/minimapColors.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common.colors;

import cityscape.base.common.Color;
import cityscape.base.common.Color.RGBA;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.EditorColors;
import cityscape.platform.theme.common.colors.MiscColors;

/**
 * The color ids of minimapColors.ts (the constants of the module) and their
 * registration, run once when the color registry is built
 * (`ColorRegistry.registerAllColors`).
 */
class MinimapColors {

    public static inline final minimapFindMatch:ColorIdentifier = 'minimap.findMatchHighlight';
    public static inline final minimapSelectionOccurrenceHighlight:ColorIdentifier = 'minimap.selectionOccurrenceHighlight';
    public static inline final minimapSelection:ColorIdentifier = 'minimap.selectionHighlight';
    public static inline final minimapInfo:ColorIdentifier = 'minimap.infoHighlight';
    public static inline final minimapWarning:ColorIdentifier = 'minimap.warningHighlight';
    public static inline final minimapError:ColorIdentifier = 'minimap.errorHighlight';
    public static inline final minimapBackground:ColorIdentifier = 'minimap.background';
    public static inline final minimapForegroundOpacity:ColorIdentifier = 'minimap.foregroundOpacity';
    public static inline final minimapSliderBackground:ColorIdentifier = 'minimapSlider.background';
    public static inline final minimapSliderHoverBackground:ColorIdentifier = 'minimapSlider.hoverBackground';
    public static inline final minimapSliderActiveBackground:ColorIdentifier = 'minimapSlider.activeBackground';

    @:allow(cityscape.platform.theme.common.ColorRegistry)
    static function registerColors():Void {

        ColorUtils.registerColor(minimapFindMatch,
            { light: '#d18616', dark: '#d18616', hcDark: '#AB5A00', hcLight: '#0F4A85' },
            'Minimap marker color for find matches.',
            true);

        ColorUtils.registerColor(minimapSelectionOccurrenceHighlight,
            { light: '#c9c9c9', dark: '#676767', hcDark: '#ffffff', hcLight: '#0F4A85' },
            'Minimap marker color for repeating editor selections.',
            true);

        ColorUtils.registerColor(minimapSelection,
            { light: '#ADD6FF', dark: '#264F78', hcDark: '#ffffff', hcLight: '#0F4A85' },
            'Minimap marker color for the editor selection.',
            true);

        ColorUtils.registerColor(minimapInfo,
            { dark: EditorColors.editorInfoForeground, light: EditorColors.editorInfoForeground, hcDark: EditorColors.editorInfoBorder, hcLight: EditorColors.editorInfoBorder },
            'Minimap marker color for infos.');

        ColorUtils.registerColor(minimapWarning,
            { dark: EditorColors.editorWarningForeground, light: EditorColors.editorWarningForeground, hcDark: EditorColors.editorWarningBorder, hcLight: EditorColors.editorWarningBorder },
            'Minimap marker color for warnings.');

        ColorUtils.registerColor(minimapError,
            { dark: new Color(new RGBA(255, 18, 18, 0.7)), light: new Color(new RGBA(255, 18, 18, 0.7)), hcDark: new Color(new RGBA(255, 50, 50, 1)), hcLight: '#B5200D' },
            'Minimap marker color for errors.');

        ColorUtils.registerColor(minimapBackground,
            null,
            'Minimap background color.');

        ColorUtils.registerColor(minimapForegroundOpacity,
            Color.fromHex('#000f'),
            'Opacity of foreground elements rendered in the minimap. For example, "#000000c0" will render the elements with 75% opacity.');

        ColorUtils.registerColor(minimapSliderBackground,
            ColorUtils.transparent(MiscColors.scrollbarSliderBackground, 0.5),
            'Minimap slider background color.');

        ColorUtils.registerColor(minimapSliderHoverBackground,
            ColorUtils.transparent(MiscColors.scrollbarSliderHoverBackground, 0.5),
            'Minimap slider background color when hovering.');

        ColorUtils.registerColor(minimapSliderActiveBackground,
            ColorUtils.transparent(MiscColors.scrollbarSliderActiveBackground, 0.5),
            'Minimap slider background color when clicked on.');

    }

}
