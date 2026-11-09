// Ported from vscode src/vs/platform/theme/common/colors/baseColors.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common.colors;

import cityscape.base.common.Color;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;

/**
 * The color ids of baseColors.ts (the constants of the module) and their
 * registration, run once when the color registry is built
 * (`ColorRegistry.registerAllColors`).
 */
class BaseColors {

    public static inline final foreground:ColorIdentifier = 'foreground';
    public static inline final disabledForeground:ColorIdentifier = 'disabledForeground';
    public static inline final errorForeground:ColorIdentifier = 'errorForeground';
    public static inline final descriptionForeground:ColorIdentifier = 'descriptionForeground';
    public static inline final iconForeground:ColorIdentifier = 'icon.foreground';
    public static inline final focusBorder:ColorIdentifier = 'focusBorder';
    public static inline final contrastBorder:ColorIdentifier = 'contrastBorder';
    public static inline final activeContrastBorder:ColorIdentifier = 'contrastActiveBorder';
    public static inline final selectionBackground:ColorIdentifier = 'selection.background';
    // ------ text link
    public static inline final textLinkForeground:ColorIdentifier = 'textLink.foreground';
    public static inline final textLinkActiveForeground:ColorIdentifier = 'textLink.activeForeground';
    public static inline final textSeparatorForeground:ColorIdentifier = 'textSeparator.foreground';
    // ------ text preformat
    public static inline final textPreformatForeground:ColorIdentifier = 'textPreformat.foreground';
    public static inline final textPreformatBackground:ColorIdentifier = 'textPreformat.background';
    // ------ text block quote
    public static inline final textBlockQuoteBackground:ColorIdentifier = 'textBlockQuote.background';
    public static inline final textBlockQuoteBorder:ColorIdentifier = 'textBlockQuote.border';
    // ------ text code block
    public static inline final textCodeBlockBackground:ColorIdentifier = 'textCodeBlock.background';

    @:allow(cityscape.platform.theme.common.ColorRegistry)
    static function registerColors():Void {

        ColorUtils.registerColor(foreground,
            { dark: '#CCCCCC', light: '#616161', hcDark: '#FFFFFF', hcLight: '#292929' },
            'Overall foreground color. This color is only used if not overridden by a component.');

        ColorUtils.registerColor(disabledForeground,
            { dark: '#CCCCCC80', light: '#61616180', hcDark: '#A5A5A5', hcLight: '#7F7F7F' },
            'Overall foreground for disabled elements. This color is only used if not overridden by a component.');

        ColorUtils.registerColor(errorForeground,
            { dark: '#F48771', light: '#A1260D', hcDark: '#F48771', hcLight: '#B5200D' },
            'Overall foreground color for error messages. This color is only used if not overridden by a component.');

        ColorUtils.registerColor(descriptionForeground,
            { light: '#717171', dark: ColorUtils.transparent(foreground, 0.7), hcDark: ColorUtils.transparent(foreground, 0.7), hcLight: ColorUtils.transparent(foreground, 0.7) },
            'Foreground color for description text providing additional information, for example for a label.');

        ColorUtils.registerColor(iconForeground,
            { dark: '#C5C5C5', light: '#424242', hcDark: '#FFFFFF', hcLight: '#292929' },
            'The default color for icons in the workbench.');

        ColorUtils.registerColor(focusBorder,
            { dark: '#007FD4', light: '#0090F1', hcDark: '#F38518', hcLight: '#006BBD' },
            'Overall border color for focused elements. This color is only used if not overridden by a component.');

        ColorUtils.registerColor(contrastBorder,
            { light: null, dark: null, hcDark: '#6FC3DF', hcLight: '#0F4A85' },
            'An extra border around elements to separate them from others for greater contrast.');

        ColorUtils.registerColor(activeContrastBorder,
            { light: null, dark: null, hcDark: focusBorder, hcLight: focusBorder },
            'An extra border around active elements to separate them from others for greater contrast.');

        ColorUtils.registerColor(selectionBackground,
            null,
            'The background color of text selections in the workbench (e.g. for input fields or text areas). Note that this does not apply to selections within the editor.');

        // ------ text link
        ColorUtils.registerColor(textLinkForeground,
            { light: '#006AB1', dark: '#3794FF', hcDark: '#21A6FF', hcLight: '#0F4A85' },
            'Foreground color for links in text.');

        ColorUtils.registerColor(textLinkActiveForeground,
            { light: '#006AB1', dark: '#3794FF', hcDark: '#21A6FF', hcLight: '#0F4A85' },
            'Foreground color for links in text when clicked on and on mouse hover.');

        ColorUtils.registerColor(textSeparatorForeground,
            { light: '#0000002e', dark: '#ffffff2e', hcDark: Color.black, hcLight: '#292929' },
            'Color for text separators.');

        // ------ text preformat
        ColorUtils.registerColor(textPreformatForeground,
            { light: '#A31515', dark: '#D7BA7D', hcDark: '#000000', hcLight: '#FFFFFF' },
            'Foreground color for preformatted text segments.');

        ColorUtils.registerColor(textPreformatBackground,
            { light: '#0000001A', dark: '#FFFFFF1A', hcDark: '#FFFFFF', hcLight: '#09345f' },
            'Background color for preformatted text segments.');

        // ------ text block quote
        ColorUtils.registerColor(textBlockQuoteBackground,
            { light: '#f2f2f2', dark: '#222222', hcDark: null, hcLight: '#F2F2F2' },
            'Background color for block quotes in text.');

        ColorUtils.registerColor(textBlockQuoteBorder,
            { light: '#007acc80', dark: '#007acc80', hcDark: Color.white, hcLight: '#292929' },
            'Border color for block quotes in text.');

        // ------ text code block
        ColorUtils.registerColor(textCodeBlockBackground,
            { light: '#dcdcdc66', dark: '#0a0a0a66', hcDark: Color.black, hcLight: '#F2F2F2' },
            'Background color for code blocks in text.');

    }

}
