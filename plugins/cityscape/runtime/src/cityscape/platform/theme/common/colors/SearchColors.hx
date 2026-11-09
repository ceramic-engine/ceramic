// Ported from vscode src/vs/platform/theme/common/colors/searchColors.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common.colors;

import cityscape.base.common.Color;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.BaseColors;
import cityscape.platform.theme.common.colors.EditorColors;

/**
 * The color ids of searchColors.ts (the constants of the module) and their
 * registration, run once when the color registry is built
 * (`ColorRegistry.registerAllColors`).
 */
class SearchColors {

    public static inline final searchResultsInfoForeground:ColorIdentifier = 'search.resultsInfoForeground';
    // ----- search editor (Distinct from normal editor find match to allow for better differentiation)
    public static inline final searchEditorFindMatch:ColorIdentifier = 'searchEditor.findMatchBackground';
    public static inline final searchEditorFindMatchBorder:ColorIdentifier = 'searchEditor.findMatchBorder';

    @:allow(cityscape.platform.theme.common.ColorRegistry)
    static function registerColors():Void {

        ColorUtils.registerColor(searchResultsInfoForeground,
            { light: BaseColors.foreground, dark: ColorUtils.transparent(BaseColors.foreground, 0.65), hcDark: BaseColors.foreground, hcLight: BaseColors.foreground },
            'Color of the text in the search viewlet\'s completion message.');

        // ----- search editor (Distinct from normal editor find match to allow for better differentiation)
        ColorUtils.registerColor(searchEditorFindMatch,
            { light: ColorUtils.transparent(EditorColors.editorFindMatchHighlight, 0.66), dark: ColorUtils.transparent(EditorColors.editorFindMatchHighlight, 0.66), hcDark: EditorColors.editorFindMatchHighlight, hcLight: EditorColors.editorFindMatchHighlight },
            'Color of the Search Editor query matches.');

        ColorUtils.registerColor(searchEditorFindMatchBorder,
            { light: ColorUtils.transparent(EditorColors.editorFindMatchHighlightBorder, 0.66), dark: ColorUtils.transparent(EditorColors.editorFindMatchHighlightBorder, 0.66), hcDark: EditorColors.editorFindMatchHighlightBorder, hcLight: EditorColors.editorFindMatchHighlightBorder },
            'Border color of the Search Editor query matches.');

    }

}
