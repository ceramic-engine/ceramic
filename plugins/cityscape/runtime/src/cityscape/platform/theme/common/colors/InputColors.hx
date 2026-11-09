// Ported from vscode src/vs/platform/theme/common/colors/inputColors.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common.colors;

import cityscape.base.common.Color;
import cityscape.base.common.Color.RGBA;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.BaseColors;
import cityscape.platform.theme.common.colors.EditorColors;

/**
 * The color ids of inputColors.ts (the constants of the module) and their
 * registration, run once when the color registry is built
 * (`ColorRegistry.registerAllColors`).
 */
class InputColors {

    // ----- input
    public static inline final inputBackground:ColorIdentifier = 'input.background';
    public static inline final inputForeground:ColorIdentifier = 'input.foreground';
    public static inline final inputBorder:ColorIdentifier = 'input.border';
    public static inline final inputActiveOptionBorder:ColorIdentifier = 'inputOption.activeBorder';
    public static inline final inputActiveOptionHoverBackground:ColorIdentifier = 'inputOption.hoverBackground';
    public static inline final inputActiveOptionBackground:ColorIdentifier = 'inputOption.activeBackground';
    public static inline final inputActiveOptionForeground:ColorIdentifier = 'inputOption.activeForeground';
    public static inline final inputPlaceholderForeground:ColorIdentifier = 'input.placeholderForeground';
    // ----- input validation
    public static inline final inputValidationInfoBackground:ColorIdentifier = 'inputValidation.infoBackground';
    public static inline final inputValidationInfoForeground:ColorIdentifier = 'inputValidation.infoForeground';
    public static inline final inputValidationInfoBorder:ColorIdentifier = 'inputValidation.infoBorder';
    public static inline final inputValidationWarningBackground:ColorIdentifier = 'inputValidation.warningBackground';
    public static inline final inputValidationWarningForeground:ColorIdentifier = 'inputValidation.warningForeground';
    public static inline final inputValidationWarningBorder:ColorIdentifier = 'inputValidation.warningBorder';
    public static inline final inputValidationErrorBackground:ColorIdentifier = 'inputValidation.errorBackground';
    public static inline final inputValidationErrorForeground:ColorIdentifier = 'inputValidation.errorForeground';
    public static inline final inputValidationErrorBorder:ColorIdentifier = 'inputValidation.errorBorder';
    // ----- select
    public static inline final selectBackground:ColorIdentifier = 'dropdown.background';
    public static inline final selectListBackground:ColorIdentifier = 'dropdown.listBackground';
    public static inline final selectForeground:ColorIdentifier = 'dropdown.foreground';
    public static inline final selectBorder:ColorIdentifier = 'dropdown.border';
    // ------ button
    public static inline final buttonForeground:ColorIdentifier = 'button.foreground';
    public static inline final buttonSeparator:ColorIdentifier = 'button.separator';
    public static inline final buttonBackground:ColorIdentifier = 'button.background';
    public static inline final buttonHoverBackground:ColorIdentifier = 'button.hoverBackground';
    public static inline final buttonBorder:ColorIdentifier = 'button.border';
    public static inline final buttonSecondaryForeground:ColorIdentifier = 'button.secondaryForeground';
    public static inline final buttonSecondaryBackground:ColorIdentifier = 'button.secondaryBackground';
    public static inline final buttonSecondaryHoverBackground:ColorIdentifier = 'button.secondaryHoverBackground';
    // ------ radio
    public static inline final radioActiveForeground:ColorIdentifier = 'radio.activeForeground';
    public static inline final radioActiveBackground:ColorIdentifier = 'radio.activeBackground';
    public static inline final radioActiveBorder:ColorIdentifier = 'radio.activeBorder';
    public static inline final radioInactiveForeground:ColorIdentifier = 'radio.inactiveForeground';
    public static inline final radioInactiveBackground:ColorIdentifier = 'radio.inactiveBackground';
    public static inline final radioInactiveBorder:ColorIdentifier = 'radio.inactiveBorder';
    public static inline final radioInactiveHoverBackground:ColorIdentifier = 'radio.inactiveHoverBackground';
    // ------ checkbox
    public static inline final checkboxBackground:ColorIdentifier = 'checkbox.background';
    public static inline final checkboxSelectBackground:ColorIdentifier = 'checkbox.selectBackground';
    public static inline final checkboxForeground:ColorIdentifier = 'checkbox.foreground';
    public static inline final checkboxBorder:ColorIdentifier = 'checkbox.border';
    public static inline final checkboxSelectBorder:ColorIdentifier = 'checkbox.selectBorder';
    // ------ keybinding label
    public static inline final keybindingLabelBackground:ColorIdentifier = 'keybindingLabel.background';
    public static inline final keybindingLabelForeground:ColorIdentifier = 'keybindingLabel.foreground';
    public static inline final keybindingLabelBorder:ColorIdentifier = 'keybindingLabel.border';
    public static inline final keybindingLabelBottomBorder:ColorIdentifier = 'keybindingLabel.bottomBorder';

    @:allow(cityscape.platform.theme.common.ColorRegistry)
    static function registerColors():Void {

        // ----- input
        ColorUtils.registerColor(inputBackground,
            { dark: '#3C3C3C', light: Color.white, hcDark: Color.black, hcLight: Color.white },
            'Input box background.');

        ColorUtils.registerColor(inputForeground,
            BaseColors.foreground,
            'Input box foreground.');

        ColorUtils.registerColor(inputBorder,
            { dark: null, light: null, hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Input box border.');

        ColorUtils.registerColor(inputActiveOptionBorder,
            { dark: '#007ACC', light: '#007ACC', hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Border color of activated options in input fields.');

        ColorUtils.registerColor(inputActiveOptionHoverBackground,
            { dark: '#5a5d5e80', light: '#b8b8b850', hcDark: null, hcLight: null },
            'Background color of activated options in input fields.');

        ColorUtils.registerColor(inputActiveOptionBackground,
            { dark: ColorUtils.transparent(BaseColors.focusBorder, 0.4), light: ColorUtils.transparent(BaseColors.focusBorder, 0.2), hcDark: Color.transparentStatic, hcLight: Color.transparentStatic },
            'Background hover color of options in input fields.');

        ColorUtils.registerColor(inputActiveOptionForeground,
            { dark: Color.white, light: Color.black, hcDark: BaseColors.foreground, hcLight: BaseColors.foreground },
            'Foreground color of activated options in input fields.');

        ColorUtils.registerColor(inputPlaceholderForeground,
            { light: ColorUtils.transparent(BaseColors.foreground, 0.5), dark: ColorUtils.transparent(BaseColors.foreground, 0.5), hcDark: ColorUtils.transparent(BaseColors.foreground, 0.7), hcLight: ColorUtils.transparent(BaseColors.foreground, 0.7) },
            'Input box foreground color for placeholder text.');

        // ----- input validation
        ColorUtils.registerColor(inputValidationInfoBackground,
            { dark: '#063B49', light: '#D6ECF2', hcDark: Color.black, hcLight: Color.white },
            'Input validation background color for information severity.');

        ColorUtils.registerColor(inputValidationInfoForeground,
            { dark: null, light: null, hcDark: null, hcLight: BaseColors.foreground },
            'Input validation foreground color for information severity.');

        ColorUtils.registerColor(inputValidationInfoBorder,
            { dark: '#007acc', light: '#007acc', hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Input validation border color for information severity.');

        ColorUtils.registerColor(inputValidationWarningBackground,
            { dark: '#352A05', light: '#F6F5D2', hcDark: Color.black, hcLight: Color.white },
            'Input validation background color for warning severity.');

        ColorUtils.registerColor(inputValidationWarningForeground,
            { dark: null, light: null, hcDark: null, hcLight: BaseColors.foreground },
            'Input validation foreground color for warning severity.');

        ColorUtils.registerColor(inputValidationWarningBorder,
            { dark: '#B89500', light: '#B89500', hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Input validation border color for warning severity.');

        ColorUtils.registerColor(inputValidationErrorBackground,
            { dark: '#5A1D1D', light: '#F2DEDE', hcDark: Color.black, hcLight: Color.white },
            'Input validation background color for error severity.');

        ColorUtils.registerColor(inputValidationErrorForeground,
            { dark: null, light: null, hcDark: null, hcLight: BaseColors.foreground },
            'Input validation foreground color for error severity.');

        ColorUtils.registerColor(inputValidationErrorBorder,
            { dark: '#BE1100', light: '#BE1100', hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Input validation border color for error severity.');

        // ----- select
        ColorUtils.registerColor(selectBackground,
            { dark: '#3C3C3C', light: Color.white, hcDark: Color.black, hcLight: Color.white },
            'Dropdown background.');

        ColorUtils.registerColor(selectListBackground,
            { dark: null, light: null, hcDark: Color.black, hcLight: Color.white },
            'Dropdown list background.');

        ColorUtils.registerColor(selectForeground,
            { dark: '#F0F0F0', light: BaseColors.foreground, hcDark: Color.white, hcLight: BaseColors.foreground },
            'Dropdown foreground.');

        ColorUtils.registerColor(selectBorder,
            { dark: selectBackground, light: '#CECECE', hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Dropdown border.');

        // ------ button
        ColorUtils.registerColor(buttonForeground,
            Color.white,
            'Button foreground color.');

        ColorUtils.registerColor(buttonSeparator,
            ColorUtils.transparent(buttonForeground, 0.4),
            'Button separator color.');

        ColorUtils.registerColor(buttonBackground,
            { dark: '#0E639C', light: '#007ACC', hcDark: null, hcLight: '#0F4A85' },
            'Button background color.');

        ColorUtils.registerColor(buttonHoverBackground,
            { dark: ColorUtils.lighten(buttonBackground, 0.2), light: ColorUtils.darken(buttonBackground, 0.2), hcDark: buttonBackground, hcLight: buttonBackground },
            'Button background color when hovering.');

        ColorUtils.registerColor(buttonBorder,
            BaseColors.contrastBorder,
            'Button border color.');

        ColorUtils.registerColor(buttonSecondaryForeground,
            { dark: Color.white, light: Color.white, hcDark: Color.white, hcLight: BaseColors.foreground },
            'Secondary button foreground color.');

        ColorUtils.registerColor(buttonSecondaryBackground,
            { dark: '#3A3D41', light: '#5F6A79', hcDark: null, hcLight: Color.white },
            'Secondary button background color.');

        ColorUtils.registerColor(buttonSecondaryHoverBackground,
            { dark: ColorUtils.lighten(buttonSecondaryBackground, 0.2), light: ColorUtils.darken(buttonSecondaryBackground, 0.2), hcDark: null, hcLight: null },
            'Secondary button background color when hovering.');

        // ------ radio
        ColorUtils.registerColor(radioActiveForeground,
            inputActiveOptionForeground,
            'Foreground color of active radio option.');

        ColorUtils.registerColor(radioActiveBackground,
            inputActiveOptionBackground,
            'Background color of active radio option.');

        ColorUtils.registerColor(radioActiveBorder,
            inputActiveOptionBorder,
            'Border color of the active radio option.');

        ColorUtils.registerColor(radioInactiveForeground,
            null,
            'Foreground color of inactive radio option.');

        ColorUtils.registerColor(radioInactiveBackground,
            null,
            'Background color of inactive radio option.');

        ColorUtils.registerColor(radioInactiveBorder,
            { light: ColorUtils.transparent(radioActiveForeground, 0.2), dark: ColorUtils.transparent(radioActiveForeground, 0.2), hcDark: ColorUtils.transparent(radioActiveForeground, 0.4), hcLight: ColorUtils.transparent(radioActiveForeground, 0.2) },
            'Border color of the inactive radio option.');

        ColorUtils.registerColor(radioInactiveHoverBackground,
            inputActiveOptionHoverBackground,
            'Background color of inactive active radio option when hovering.');

        // ------ checkbox
        ColorUtils.registerColor(checkboxBackground,
            selectBackground,
            'Background color of checkbox widget.');

        ColorUtils.registerColor(checkboxSelectBackground,
            EditorColors.editorWidgetBackground,
            'Background color of checkbox widget when the element it\'s in is selected.');

        ColorUtils.registerColor(checkboxForeground,
            selectForeground,
            'Foreground color of checkbox widget.');

        ColorUtils.registerColor(checkboxBorder,
            selectBorder,
            'Border color of checkbox widget.');

        ColorUtils.registerColor(checkboxSelectBorder,
            BaseColors.iconForeground,
            'Border color of checkbox widget when the element it\'s in is selected.');

        // ------ keybinding label
        ColorUtils.registerColor(keybindingLabelBackground,
            { dark: new Color(new RGBA(128, 128, 128, 0.17)), light: new Color(new RGBA(221, 221, 221, 0.4)), hcDark: Color.transparentStatic, hcLight: Color.transparentStatic },
            'Keybinding label background color. The keybinding label is used to represent a keyboard shortcut.');

        ColorUtils.registerColor(keybindingLabelForeground,
            { dark: Color.fromHex('#CCCCCC'), light: Color.fromHex('#555555'), hcDark: Color.white, hcLight: BaseColors.foreground },
            'Keybinding label foreground color. The keybinding label is used to represent a keyboard shortcut.');

        ColorUtils.registerColor(keybindingLabelBorder,
            { dark: new Color(new RGBA(51, 51, 51, 0.6)), light: new Color(new RGBA(204, 204, 204, 0.4)), hcDark: new Color(new RGBA(111, 195, 223)), hcLight: BaseColors.contrastBorder },
            'Keybinding label border color. The keybinding label is used to represent a keyboard shortcut.');

        ColorUtils.registerColor(keybindingLabelBottomBorder,
            { dark: new Color(new RGBA(68, 68, 68, 0.6)), light: new Color(new RGBA(187, 187, 187, 0.4)), hcDark: new Color(new RGBA(111, 195, 223)), hcLight: BaseColors.foreground },
            'Keybinding label border bottom color. The keybinding label is used to represent a keyboard shortcut.');

    }

}
