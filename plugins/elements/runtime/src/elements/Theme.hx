package elements;

import tracker.Model;
import ceramic.Color;
import ceramic.BitmapFont;
import ceramic.Shortcuts.*;

class Theme extends Model {

/// Text colors

    @observe public var fieldTextColor:Color = 0xFFFFFF;

    @observe public var fieldPlaceholderColor:Color = 0x888888;

    @observe public var lightTextColor:Color = 0xF3F3F3;

    @observe public var mediumTextColor:Color = 0xCCCCCC;

    @observe public var darkTextColor:Color = 0x888888;

    @observe public var darkerTextColor:Color = 0x555555;

/// Icon colors

    @observe public var iconColor:Color = 0xFFFFFF;

/// Text fonts

    public var mediumFont(get,never):BitmapFont;
    function get_mediumFont():BitmapFont return app.assets.font(settings.defaultFont);

    public var boldFont(get,never):BitmapFont;
    function get_boldFont():BitmapFont return app.assets.font(settings.defaultFont);

/// Borders colors

    @observe public var lighterBorderColor:Color = 0x999999;

    @observe public var lightBorderColor:Color = 0x636363;

    @observe public var mediumBorderColor:Color = 0x464646;

    @observe public var darkBorderColor:Color = 0x383838;

/// Backgrounds colors

    @observe public var windowBackgroundColor:Color = 0x282828;

    @observe public var lightBackgroundColor:Color = 0x4F4F4F;

    @observe public var mediumBackgroundColor:Color = 0x4A4A4A;

    @observe public var darkBackgroundColor:Color = 0x424242;

    @observe public var darkerBackgroundColor:Color = 0x282828;

/// Selection

    @observe public var selectionBorderColor:Color = 0x4392E0;

    @observe public var highlightColor:Color = 0x4392E0;

    @observe public var highlightPendingColor:Color = 0xFE5134;

/// Field

    @observe public var focusedFieldSelectionColor:Color = 0x3073C6;

    @observe public var focusedFieldBorderColor:Color = 0x4392E0;

/// Bubble

    @observe public var overlayBackgroundColor:Color = 0x111111;

    @observe public var overlayBackgroundAlpha:Float = 0.9;

/// Button

    @observe public var buttonBackgroundColor:Color = 0x515151;

    @observe public var buttonOverBackgroundColor:Color = 0x5A5A5A;

    @observe public var buttonPressedBackgroundColor:Color = 0x4798EB;

/// Window

    @observe public var windowBorderColor:Color = 0x636363;

    @observe public var windowBorderAlpha:Float = 1;

    public function new() {

        super();

    }

}
