// Ported from vscode src/vs/editor/common/editorTheme.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.Color;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.Theme.ColorScheme;
import cityscape.platform.theme.common.ThemeService.IColorTheme;

class EditorTheme {

    var _theme:IColorTheme;

    public var type(get, never):ColorScheme;

    function get_type():ColorScheme {
        return this._theme.type;
    }

    public var value(get, never):IColorTheme;

    function get_value():IColorTheme {
        return this._theme;
    }

    public function new(theme:IColorTheme) {
        this._theme = theme;
    }

    public function update(theme:IColorTheme):Void {
        this._theme = theme;
    }

    public function getColor(color:ColorIdentifier):Null<Color> {
        return this._theme.getColor(color);
    }

}
