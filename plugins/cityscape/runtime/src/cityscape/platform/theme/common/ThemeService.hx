// Ported from vscode src/vs/platform/theme/common/themeService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common;

import cityscape.base.common.Color;
import cityscape.base.common.Event;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.Theme.ColorScheme;

/**
 * The part of themeService.ts the editor uses: the color theme and the
 * theme service. TODO: file icon and product icon themes, theming
 * participants (CSS) and `Themable` are not ported.
 */
class ThemeService {

    public static function themeColorFromId(id:ColorIdentifier):cityscape.base.common.Themables.ThemeColor {
        return {id: id};
    }

    public static function getThemeTypeSelector(type:ColorScheme):String {
        return switch (type) {
            case ColorScheme.DARK: 'vs-dark';
            case ColorScheme.HIGH_CONTRAST_DARK: 'hc-black';
            case ColorScheme.HIGH_CONTRAST_LIGHT: 'hc-light';
            default: 'vs';
        }
    }

}

typedef ITokenStyle = {
    final foreground:Null<Int>;
    final bold:Null<Bool>;
    final underline:Null<Bool>;
    final strikethrough:Null<Bool>;
    final italic:Null<Bool>;
}

interface IColorTheme {

    var type(get, never):ColorScheme;

    var label(get, never):String;

    /**
     * Resolves the color of the current theme with the given id. `useDefault`
     * (true when not given) resolves the color from the registry defaults
     * when the theme does not define it.
     */
    function getColor(color:ColorIdentifier, ?useDefault:Bool):Null<Color>;

    /**
     * Returns whether the theme defines a value for the color. If not, that means the
     * default color will be used.
     */
    function defines(color:ColorIdentifier):Bool;

    /**
     * Returns the token style for a given classification. The result uses the <code>MetadataConsts</code> format
     */
    function getTokenStyleMetadata(type:String, modifiers:Array<String>, modelLanguage:String):Null<ITokenStyle>;

    /**
     * List of all colors used with tokens. <code>getTokenStyleMetadata</code> references the colors by index into this list.
     */
    var tokenColorMap(get, never):Array<String>;

    /**
     * Defines whether semantic highlighting should be enabled for the theme.
     */
    var semanticHighlighting(get, never):Bool;

}

interface IThemeService {

    function getColorTheme():IColorTheme;

    var onDidColorThemeChange(default, null):Event<IColorTheme>;

}
