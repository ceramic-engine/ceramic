package elements;

import ceramic.BitmapFont;
import ceramic.Color;
import ceramic.FontAsset;
import ceramic.Shortcuts.*;
import tracker.Model;

class Theme extends Model {

/// Behaviors

    @serialize public var backgroundInFormLayout:Bool = false;

/// Text colors

    @serialize public var fieldTextColor:Color = 0xFFFFFF;

    @serialize public var fieldPlaceholderColor:Color = 0x888888;

    @serialize public var lightTextColor:Color = 0xF3F3F3;

    @serialize public var mediumTextColor:Color = 0xCCCCCC;

    @serialize public var darkTextColor:Color = 0x888888;

    @serialize public var darkerTextColor:Color = 0x555555;

/// Icon colors

    @serialize public var iconColor:Color = 0xFFFFFF;

/// Text fonts

    @serialize public var customMediumFont:BitmapFont = null;

    public var mediumFont(get,never):BitmapFont;
    function get_mediumFont():BitmapFont {
        var font = customMediumFont;
        return font != null ? font : app.assets.font(settings.defaultFont);
    }

    @serialize public var customBoldFont:BitmapFont = null;

    public var boldFont(get,never):BitmapFont;
    function get_boldFont():BitmapFont {
        var font = customBoldFont;
        return font != null ? font : app.assets.font(settings.defaultFont);
    }

/// Borders colors

    @serialize public var lighterBorderColor:Color = 0x999999;

    @serialize public var lightBorderColor:Color = 0x636363;

    @serialize public var mediumBorderColor:Color = 0x464646;

    @serialize public var darkBorderColor:Color = 0x383838;

/// Backgrounds colors

    @serialize public var lightBackgroundColor:Color = 0x4F4F4F;

    @serialize public var mediumBackgroundColor:Color = 0x4A4A4A;

    @serialize public var darkBackgroundColor:Color = 0x424242;

    @serialize public var darkerBackgroundColor:Color = 0x282828;

/// Selection

    @serialize public var selectionBorderColor:Color = 0x4392E0;

    @serialize public var highlightColor:Color = 0x4392E0;

    @serialize public var highlightPendingColor:Color = 0xFE5134;

/// Form

    @serialize public var formItemSpacing:Float = 6;

    @serialize public var formPadding:Float = 6;

    @serialize public var tabsMarginY:Float = 6;

/// Field

    @serialize public var focusedFieldSelectionColor:Color = 0x3073C6;

    @serialize public var focusedFieldBorderColor:Color = 0x4392E0;

/// Overlay

    @serialize public var overlayBackgroundColor:Color = 0x1C1C1C;

    @serialize public var overlayBackgroundAlpha:Float = 0.925;

    @serialize public var overlayBorderColor:Color = 0x636363;

    @serialize public var overlayBorderAlpha:Float = 1;

/// Button

    @serialize public var buttonBackgroundColor:Color = 0x515151;

    @serialize public var buttonOverBackgroundColor:Color = 0x5A5A5A;

    @serialize public var buttonPressedBackgroundColor:Color = 0x4798EB;

    @serialize public var buttonFocusedBorderColor:Color = 0x4798EB;

/// Tabs

    @serialize public var tabsBackgroundColor:Color = 0x888888;

    @serialize public var tabsBackgroundAlpha:Float = 0.1;

    @serialize public var tabsHoverBackgroundColor:Color = 0x888888;

    @serialize public var tabsHoverBackgroundAlpha:Float = 0.2;

    @serialize public var tabsBorderColor:Color = 0x636363;

    @serialize public var disabledTabTextAlpha:Float = 0.5;

    @serialize public var disabledTabBorderAlpha:Float = 0.5;

/// Window

    @serialize public var windowBackgroundColor:Color = 0x1C1C1C;

    @serialize public var windowBackgroundAlpha:Float = 0.925;

    @serialize public var windowBorderColor:Color = 0x636363;

    @serialize public var windowBorderAlpha:Float = 1;

    public function new() {

        super();

    }

/// Helpers

    public function clone(?toTheme:Theme):Theme {

        if (toTheme == null)
            toTheme = new Theme();

        toTheme.backgroundInFormLayout = backgroundInFormLayout;
        toTheme.fieldTextColor = fieldTextColor;
        toTheme.fieldPlaceholderColor = fieldPlaceholderColor;
        toTheme.lightTextColor = lightTextColor;
        toTheme.mediumTextColor = mediumTextColor;
        toTheme.darkTextColor = darkTextColor;
        toTheme.darkerTextColor = darkerTextColor;
        toTheme.iconColor = iconColor;
        toTheme.customMediumFont = customMediumFont;
        toTheme.lighterBorderColor = lighterBorderColor;
        toTheme.lightBorderColor = lightBorderColor;
        toTheme.mediumBorderColor = mediumBorderColor;
        toTheme.darkBorderColor = darkBorderColor;
        toTheme.lightBackgroundColor = lightBackgroundColor;
        toTheme.mediumBackgroundColor = mediumBackgroundColor;
        toTheme.darkBackgroundColor = darkBackgroundColor;
        toTheme.darkerBackgroundColor = darkerBackgroundColor;
        toTheme.selectionBorderColor = selectionBorderColor;
        toTheme.highlightColor = highlightColor;
        toTheme.highlightPendingColor = highlightPendingColor;
        toTheme.formItemSpacing = formItemSpacing;
        toTheme.formPadding = formPadding;
        toTheme.tabsMarginY = tabsMarginY;
        toTheme.focusedFieldSelectionColor = focusedFieldSelectionColor;
        toTheme.focusedFieldBorderColor = focusedFieldBorderColor;
        toTheme.overlayBackgroundColor = overlayBackgroundColor;
        toTheme.overlayBackgroundAlpha = overlayBackgroundAlpha;
        toTheme.overlayBorderColor = overlayBorderColor;
        toTheme.overlayBorderAlpha = overlayBorderAlpha;
        toTheme.buttonBackgroundColor = buttonBackgroundColor;
        toTheme.buttonOverBackgroundColor = buttonOverBackgroundColor;
        toTheme.buttonPressedBackgroundColor = buttonPressedBackgroundColor;
        toTheme.buttonFocusedBorderColor = buttonFocusedBorderColor;
        toTheme.tabsBackgroundColor = tabsBackgroundColor;
        toTheme.tabsBackgroundAlpha = tabsBackgroundAlpha;
        toTheme.tabsHoverBackgroundColor = tabsHoverBackgroundColor;
        toTheme.tabsHoverBackgroundAlpha = tabsHoverBackgroundAlpha;
        toTheme.tabsBorderColor = tabsBorderColor;
        toTheme.windowBackgroundColor = windowBackgroundColor;
        toTheme.windowBackgroundAlpha = windowBackgroundAlpha;
        toTheme.windowBorderColor = windowBorderColor;
        toTheme.windowBorderAlpha = windowBorderAlpha;

        toTheme._clonedIndex = _index;

        return toTheme;

    }

    /**
     * Apply the given `tint` color using `baseTheme` as lightness references
     */
    public function applyTint(?baseTheme:Theme, tint:Color):Void {

        if (baseTheme == null)
            baseTheme = Context.context.theme;

        var tintHue = tint.hueHSLuv;
        var tintSaturation = tint.saturationHSLuv;
        var tintLightness = tint.lightnessHSLuv;

        inline function computeColor(color:Color):Color {
            return Color.fromHSLuv(
                tintHue,
                tintSaturation,
                Math.max(0.0, Math.min(1.0, (color.lightnessHSLuv * 2.0 + tintLightness - 0.5) * 0.5))
            );
        }

        fieldTextColor = computeColor(baseTheme.fieldTextColor);
        fieldPlaceholderColor = computeColor(baseTheme.fieldPlaceholderColor);
        lightTextColor = computeColor(baseTheme.lightTextColor);
        mediumTextColor = computeColor(baseTheme.mediumTextColor);
        darkTextColor = computeColor(baseTheme.darkTextColor);
        darkerTextColor = computeColor(baseTheme.darkerTextColor);

        iconColor = computeColor(baseTheme.iconColor);

        lighterBorderColor = computeColor(baseTheme.lighterBorderColor);
        lightBorderColor = computeColor(baseTheme.lightBorderColor);
        mediumBorderColor = computeColor(baseTheme.mediumBorderColor);
        darkBorderColor = computeColor(baseTheme.darkBorderColor);

        lightBackgroundColor = computeColor(baseTheme.lightBackgroundColor);
        mediumBackgroundColor = computeColor(baseTheme.mediumBackgroundColor);
        darkBackgroundColor = computeColor(baseTheme.darkBackgroundColor);
        darkerBackgroundColor = computeColor(baseTheme.darkerBackgroundColor);

        overlayBackgroundColor = computeColor(baseTheme.overlayBackgroundColor);
        overlayBorderColor = computeColor(baseTheme.overlayBorderColor);

        buttonBackgroundColor = computeColor(baseTheme.buttonBackgroundColor);
        buttonOverBackgroundColor = computeColor(baseTheme.buttonOverBackgroundColor);
        buttonPressedBackgroundColor = computeColor(baseTheme.buttonPressedBackgroundColor);

        tabsBackgroundColor = computeColor(baseTheme.tabsBackgroundColor);
        tabsHoverBackgroundColor = computeColor(baseTheme.tabsHoverBackgroundColor);
        tabsBorderColor = computeColor(baseTheme.tabsBorderColor);

        windowBackgroundColor = computeColor(baseTheme.windowBackgroundColor);
        windowBorderColor = computeColor(baseTheme.windowBorderColor);

    }

    /**
     * Apply the given alt `tint` color using `baseTheme` as lightness references
     */
    public function applyAltTint(?baseTheme:Theme, tint:Color):Void {

        if (baseTheme == null)
            baseTheme = Context.context.theme;

        var tintHue = tint.hueHSLuv;
        var tintSaturation = tint.saturationHSLuv;
        var tintLightness = tint.lightnessHSLuv;

        inline function computeColor(color:Color):Color {
            return Color.fromHSLuv(
                tintHue,
                tintSaturation,
                Math.max(0.0, Math.min(1.0, (color.lightnessHSLuv * 2.0 + tintLightness - 0.5) * 0.5))
            );
        }

        selectionBorderColor = computeColor(baseTheme.selectionBorderColor);
        highlightColor = computeColor(baseTheme.highlightColor);
        highlightPendingColor = computeColor(baseTheme.highlightPendingColor);

        focusedFieldSelectionColor = computeColor(baseTheme.focusedFieldSelectionColor);
        focusedFieldBorderColor = computeColor(baseTheme.focusedFieldBorderColor);

        buttonFocusedBorderColor = computeColor(baseTheme.buttonFocusedBorderColor);

    }

    public function applyBackgroundColor(color:Color):Void {

        tabsBackgroundColor = color;
        windowBackgroundColor = color;

    }

    public function applyTextColor(color:Color):Void {

        lightTextColor = color;
        mediumTextColor = color;
        darkTextColor = color;
        darkerTextColor = color;

    }

/// Internals for Im

    static var _nextIndex:Int = 1;

    @:allow(elements.Im)
    private var _tint:Color = Color.NONE;

    @:allow(elements.Im)
    private var _altTint:Color = Color.NONE;

    @:allow(elements.Im)
    private var _backgroundColor:Color = Color.NONE;

    @:allow(elements.Im)
    private var _textColor:Color = Color.NONE;

    @:allow(elements.Im)
    private var _used:Bool = false;

    @:allow(elements.Im)
    private var _index:Int = (_nextIndex = (_nextIndex + 1) % 999999999);

    @:allow(elements.Im)
    private var _clonedIndex:Int = -1;

}
