// Ported from vscode src/vs/platform/theme/common/colorRegistry.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common;

import cityscape.common.core.EditorColorRegistry;
import cityscape.platform.theme.common.colors.BaseColors;
import cityscape.platform.theme.common.colors.EditorColors;
import cityscape.platform.theme.common.colors.InputColors;
import cityscape.platform.theme.common.colors.ListColors;
import cityscape.platform.theme.common.colors.MenuColors;
import cityscape.platform.theme.common.colors.MinimapColors;
import cityscape.platform.theme.common.colors.MiscColors;
import cityscape.platform.theme.common.colors.QuickpickColors;
import cityscape.platform.theme.common.colors.SearchColors;

/**
 * colorRegistry.ts re-exports colorUtils.ts and makes sure all color files
 * are loaded (their registrations run). Here the color constants stay in
 * their classes (`BaseColors.foreground`, `EditorColors.editorBackground`...)
 * and `registerAllColors` runs the registrations once, when
 * `ColorUtils.getColorRegistry()` builds the registry.
 *
 * chartsColors.ts is not registered (no charts in the editor).
 * editorColorRegistry.ts (editor/common/core), which Monaco loads with the
 * editor, is registered here too.
 */
class ColorRegistry {

    @:allow(cityscape.platform.theme.common.ColorUtils)
    static function registerAllColors():Void {
        BaseColors.registerColors();
        EditorColors.registerColors();
        InputColors.registerColors();
        ListColors.registerColors();
        MenuColors.registerColors();
        MinimapColors.registerColors();
        MiscColors.registerColors();
        QuickpickColors.registerColors();
        SearchColors.registerColors();
        EditorColorRegistry.registerColors();
        // Colors of the editor contributions (registered when Monaco loads them)
        cityscape.contrib.folding.view.FoldingDecorations.FoldingColors.registerColors();
        cityscape.contrib.peekView.view.PeekView.PeekViewColors.registerColors();
    }

}
