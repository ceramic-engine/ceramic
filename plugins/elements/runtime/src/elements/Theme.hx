package elements;

import ceramic.BitmapFont;
import ceramic.Color;
import ceramic.Shortcuts.*;
import tracker.Model;

class Theme extends Model {

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

    public var mediumFont(get,never):BitmapFont;
    function get_mediumFont():BitmapFont return app.assets.font(settings.defaultFont);

    public var boldFont(get,never):BitmapFont;
    function get_boldFont():BitmapFont return app.assets.font(settings.defaultFont);

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

/// Window

    @serialize public var windowBackgroundColor:Color = 0x1C1C1C;

    @serialize public var windowBackgroundAlpha:Float = 0.925;

    @serialize public var windowBorderColor:Color = 0x636363;

    @serialize public var windowBorderAlpha:Float = 1;

    public function new() {

        super();

    }

}
