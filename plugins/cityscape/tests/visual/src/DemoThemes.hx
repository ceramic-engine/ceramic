// New code for Cityscape (not a port): the VS Code themes of the visual
// check (Dark+ and Light+), so that TextMate scopes are colored like VS Code.
package;

import cityscape.Cityscape;
import cityscape.standalone.common.VSCodeTheme;

/**
 * VS Code's Dark+ and Light+ themes for the demo scenes.
 *
 * Monaco's built-in `vs-dark` and `vs` themes have rules for Monarch tokens:
 * the TextMate scopes of the bundled grammars (`storage.*`, `entity.*`...)
 * stay uncolored with them. The scenes use VS Code's default themes instead:
 * the token rules are the theme files of vscode-textmate's fixtures
 * (`dark_plus.json` including `dark_vs.json`, `light_plus.json` including
 * `light_vs.json`), their `include` resolved like vscode-textmate's theme
 * tests and `TextMateTruthTest` do (the included settings first), and the
 * editor colors are those VS Code gives these themes (the `colors` of
 * `dark_vs.json` and `light_vs.json` in VS Code's theme-defaults extension)
 * over Monaco's dark and light defaults.
 */
class DemoThemes {

    /**
     * The editor colors of VS Code's `dark_vs.json` (theme-defaults).
     */
    static final DARK_COLORS:Dynamic = {
        'editor.background': '#1E1E1E',
        'editor.foreground': '#D4D4D4',
        'editor.inactiveSelectionBackground': '#3A3D41',
        'editorIndentGuide.background1': '#404040',
        'editorIndentGuide.activeBackground1': '#707070',
        'editor.selectionHighlightBackground': '#ADD6FF26'
    };

    /**
     * The editor colors of VS Code's `light_vs.json` (theme-defaults).
     */
    static final LIGHT_COLORS:Dynamic = {
        'editor.background': '#FFFFFF',
        'editor.foreground': '#000000',
        'editor.inactiveSelectionBackground': '#E5EBF1',
        'editorIndentGuide.background1': '#D3D3D3',
        'editorIndentGuide.activeBackground1': '#939393',
        'editor.selectionHighlightBackground': '#ADD6FF80',
        'editorSuggestWidget.background': '#F3F3F3'
    };

    /**
     * A theme of the fixtures with its `include` resolved: the included
     * theme's settings first, then its own.
     */
    static function resolve(text:String, included:String, type:String, colors:Dynamic):Dynamic {
        final theme:Dynamic = haxe.Json.parse(text);
        final base:Dynamic = haxe.Json.parse(included);
        final settings:Array<Dynamic> = (base.settings : Array<Dynamic>).concat(theme.settings);
        return {
            name: theme.name,
            type: type,
            colors: colors,
            settings: settings
        };
    }

    public static function darkPlus():Dynamic {
        return resolve(
            Embed.file('../../../../../git/textmate/test/fixtures/vscode-textmate/themes/dark_plus.json'),
            Embed.file('../../../../../git/textmate/test/fixtures/vscode-textmate/themes/dark_vs.json'),
            'dark',
            DARK_COLORS
        );
    }

    public static function lightPlus():Dynamic {
        return resolve(
            Embed.file('../../../../../git/textmate/test/fixtures/vscode-textmate/themes/light_plus.json'),
            Embed.file('../../../../../git/textmate/test/fixtures/vscode-textmate/themes/light_vs.json'),
            'light',
            LIGHT_COLORS
        );
    }

    /**
     * Defines `dark-plus` and `light-plus` in `context` and sets one.
     */
    public static function apply(context:Cityscape, dark:Bool):Void {
        context.themeService.defineTheme('dark-plus', VSCodeTheme.toStandaloneThemeData(darkPlus()));
        context.themeService.defineTheme('light-plus', VSCodeTheme.toStandaloneThemeData(lightPlus()));
        context.themeService.setTheme(dark ? 'dark-plus' : 'light-plus');
    }

}
