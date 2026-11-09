// Ported from vscode src/vs/base/common/themables.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * A color of the theme, by its key (`editor.background`...).
 */
typedef ThemeColor = {
    var id:String;
}

/**
 * An icon of the theme (codicon id), with an optional color.
 */
typedef ThemeIcon = {
    final id:String;
    @:optional final color:ThemeColor;
}

class Themables {

    /**
     * `ThemeColor.isThemeColor`: whether `obj` is an object with a string `id`.
     */
    public static function isThemeColor(obj:Any):Bool {
        return JsValues.isObject(obj) && JsValues.isString(JsValues.field(obj, 'id'));
    }

}
