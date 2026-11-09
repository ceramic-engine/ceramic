// Ported from vscode src/vs/editor/common/core/editorColorRegistry.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.Color;
import cityscape.base.common.Color.RGBA;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.colors.BaseColors;
import cityscape.platform.theme.common.colors.EditorColors;

/**
 * The color ids of editorColorRegistry.ts (the constants of the module) and their
 * registration, run once when the color registry is built
 * (`ColorRegistry.registerAllColors`).
 */
class EditorColorRegistry {

    /**
     * Definition of the editor colors
     */
    public static inline final editorLineHighlight:ColorIdentifier = 'editor.lineHighlightBackground';
    public static inline final editorLineHighlightBorder:ColorIdentifier = 'editor.lineHighlightBorder';
    public static inline final editorRangeHighlight:ColorIdentifier = 'editor.rangeHighlightBackground';
    public static inline final editorRangeHighlightBorder:ColorIdentifier = 'editor.rangeHighlightBorder';
    public static inline final editorSymbolHighlight:ColorIdentifier = 'editor.symbolHighlightBackground';
    public static inline final editorSymbolHighlightBorder:ColorIdentifier = 'editor.symbolHighlightBorder';
    public static inline final editorCursorForeground:ColorIdentifier = 'editorCursor.foreground';
    public static inline final editorCursorBackground:ColorIdentifier = 'editorCursor.background';
    public static inline final editorMultiCursorPrimaryForeground:ColorIdentifier = 'editorMultiCursor.primary.foreground';
    public static inline final editorMultiCursorPrimaryBackground:ColorIdentifier = 'editorMultiCursor.primary.background';
    public static inline final editorMultiCursorSecondaryForeground:ColorIdentifier = 'editorMultiCursor.secondary.foreground';
    public static inline final editorMultiCursorSecondaryBackground:ColorIdentifier = 'editorMultiCursor.secondary.background';
    public static inline final editorWhitespaces:ColorIdentifier = 'editorWhitespace.foreground';
    public static inline final editorLineNumbers:ColorIdentifier = 'editorLineNumber.foreground';
    public static inline final deprecatedEditorIndentGuides:ColorIdentifier = 'editorIndentGuide.background';
    public static inline final deprecatedEditorActiveIndentGuides:ColorIdentifier = 'editorIndentGuide.activeBackground';
    public static inline final editorIndentGuide1:ColorIdentifier = 'editorIndentGuide.background1';
    public static inline final editorIndentGuide2:ColorIdentifier = 'editorIndentGuide.background2';
    public static inline final editorIndentGuide3:ColorIdentifier = 'editorIndentGuide.background3';
    public static inline final editorIndentGuide4:ColorIdentifier = 'editorIndentGuide.background4';
    public static inline final editorIndentGuide5:ColorIdentifier = 'editorIndentGuide.background5';
    public static inline final editorIndentGuide6:ColorIdentifier = 'editorIndentGuide.background6';
    public static inline final editorActiveIndentGuide1:ColorIdentifier = 'editorIndentGuide.activeBackground1';
    public static inline final editorActiveIndentGuide2:ColorIdentifier = 'editorIndentGuide.activeBackground2';
    public static inline final editorActiveIndentGuide3:ColorIdentifier = 'editorIndentGuide.activeBackground3';
    public static inline final editorActiveIndentGuide4:ColorIdentifier = 'editorIndentGuide.activeBackground4';
    public static inline final editorActiveIndentGuide5:ColorIdentifier = 'editorIndentGuide.activeBackground5';
    public static inline final editorActiveIndentGuide6:ColorIdentifier = 'editorIndentGuide.activeBackground6';
    static inline final deprecatedEditorActiveLineNumber:ColorIdentifier = 'editorActiveLineNumber.foreground';
    public static inline final editorActiveLineNumber:ColorIdentifier = 'editorLineNumber.activeForeground';
    public static inline final editorDimmedLineNumber:ColorIdentifier = 'editorLineNumber.dimmedForeground';
    public static inline final editorRuler:ColorIdentifier = 'editorRuler.foreground';
    public static inline final editorCodeLensForeground:ColorIdentifier = 'editorCodeLens.foreground';
    public static inline final editorBracketMatchBackground:ColorIdentifier = 'editorBracketMatch.background';
    public static inline final editorBracketMatchBorder:ColorIdentifier = 'editorBracketMatch.border';
    public static inline final editorOverviewRulerBorder:ColorIdentifier = 'editorOverviewRuler.border';
    public static inline final editorOverviewRulerBackground:ColorIdentifier = 'editorOverviewRuler.background';
    public static inline final editorGutter:ColorIdentifier = 'editorGutter.background';
    public static inline final editorUnnecessaryCodeBorder:ColorIdentifier = 'editorUnnecessaryCode.border';
    public static inline final editorUnnecessaryCodeOpacity:ColorIdentifier = 'editorUnnecessaryCode.opacity';
    public static inline final ghostTextBorder:ColorIdentifier = 'editorGhostText.border';
    public static inline final ghostTextForeground:ColorIdentifier = 'editorGhostText.foreground';
    public static inline final ghostTextBackground:ColorIdentifier = 'editorGhostText.background';
    public static inline final overviewRulerRangeHighlight:ColorIdentifier = 'editorOverviewRuler.rangeHighlightForeground';
    public static inline final overviewRulerError:ColorIdentifier = 'editorOverviewRuler.errorForeground';
    public static inline final overviewRulerWarning:ColorIdentifier = 'editorOverviewRuler.warningForeground';
    public static inline final overviewRulerInfo:ColorIdentifier = 'editorOverviewRuler.infoForeground';
    public static inline final editorBracketHighlightingForeground1:ColorIdentifier = 'editorBracketHighlight.foreground1';
    public static inline final editorBracketHighlightingForeground2:ColorIdentifier = 'editorBracketHighlight.foreground2';
    public static inline final editorBracketHighlightingForeground3:ColorIdentifier = 'editorBracketHighlight.foreground3';
    public static inline final editorBracketHighlightingForeground4:ColorIdentifier = 'editorBracketHighlight.foreground4';
    public static inline final editorBracketHighlightingForeground5:ColorIdentifier = 'editorBracketHighlight.foreground5';
    public static inline final editorBracketHighlightingForeground6:ColorIdentifier = 'editorBracketHighlight.foreground6';
    public static inline final editorBracketHighlightingUnexpectedBracketForeground:ColorIdentifier = 'editorBracketHighlight.unexpectedBracket.foreground';
    public static inline final editorBracketPairGuideBackground1:ColorIdentifier = 'editorBracketPairGuide.background1';
    public static inline final editorBracketPairGuideBackground2:ColorIdentifier = 'editorBracketPairGuide.background2';
    public static inline final editorBracketPairGuideBackground3:ColorIdentifier = 'editorBracketPairGuide.background3';
    public static inline final editorBracketPairGuideBackground4:ColorIdentifier = 'editorBracketPairGuide.background4';
    public static inline final editorBracketPairGuideBackground5:ColorIdentifier = 'editorBracketPairGuide.background5';
    public static inline final editorBracketPairGuideBackground6:ColorIdentifier = 'editorBracketPairGuide.background6';
    public static inline final editorBracketPairGuideActiveBackground1:ColorIdentifier = 'editorBracketPairGuide.activeBackground1';
    public static inline final editorBracketPairGuideActiveBackground2:ColorIdentifier = 'editorBracketPairGuide.activeBackground2';
    public static inline final editorBracketPairGuideActiveBackground3:ColorIdentifier = 'editorBracketPairGuide.activeBackground3';
    public static inline final editorBracketPairGuideActiveBackground4:ColorIdentifier = 'editorBracketPairGuide.activeBackground4';
    public static inline final editorBracketPairGuideActiveBackground5:ColorIdentifier = 'editorBracketPairGuide.activeBackground5';
    public static inline final editorBracketPairGuideActiveBackground6:ColorIdentifier = 'editorBracketPairGuide.activeBackground6';
    public static inline final editorUnicodeHighlightBorder:ColorIdentifier = 'editorUnicodeHighlight.border';
    public static inline final editorUnicodeHighlightBackground:ColorIdentifier = 'editorUnicodeHighlight.background';

    @:allow(cityscape.platform.theme.common.ColorRegistry)
    static function registerColors():Void {

        /**
         * Definition of the editor colors
         */
        ColorUtils.registerColor(editorLineHighlight,
            null,
            'Background color for the highlight of line at the cursor position.');

        ColorUtils.registerColor(editorLineHighlightBorder,
            { dark: '#282828', light: '#eeeeee', hcDark: '#f38518', hcLight: BaseColors.contrastBorder },
            'Background color for the border around the line at the cursor position.');

        ColorUtils.registerColor(editorRangeHighlight,
            { dark: '#ffffff0b', light: '#fdff0033', hcDark: null, hcLight: null },
            'Background color of highlighted ranges, like by quick open and find features. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(editorRangeHighlightBorder,
            { dark: null, light: null, hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder },
            'Background color of the border around highlighted ranges.');

        ColorUtils.registerColor(editorSymbolHighlight,
            { dark: EditorColors.editorFindMatchHighlight, light: EditorColors.editorFindMatchHighlight, hcDark: null, hcLight: null },
            'Background color of highlighted symbol, like for go to definition or go next/previous symbol. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(editorSymbolHighlightBorder,
            { dark: null, light: null, hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder },
            'Background color of the border around highlighted symbols.');

        ColorUtils.registerColor(editorCursorForeground,
            { dark: '#AEAFAD', light: Color.black, hcDark: Color.white, hcLight: '#0F4A85' },
            'Color of the editor cursor.');

        ColorUtils.registerColor(editorCursorBackground,
            null,
            'The background color of the editor cursor. Allows customizing the color of a character overlapped by a block cursor.');

        ColorUtils.registerColor(editorMultiCursorPrimaryForeground,
            editorCursorForeground,
            'Color of the primary editor cursor when multiple cursors are present.');

        ColorUtils.registerColor(editorMultiCursorPrimaryBackground,
            editorCursorBackground,
            'The background color of the primary editor cursor when multiple cursors are present. Allows customizing the color of a character overlapped by a block cursor.');

        ColorUtils.registerColor(editorMultiCursorSecondaryForeground,
            editorCursorForeground,
            'Color of secondary editor cursors when multiple cursors are present.');

        ColorUtils.registerColor(editorMultiCursorSecondaryBackground,
            editorCursorBackground,
            'The background color of secondary editor cursors when multiple cursors are present. Allows customizing the color of a character overlapped by a block cursor.');

        ColorUtils.registerColor(editorWhitespaces,
            { dark: '#e3e4e229', light: '#33333333', hcDark: '#e3e4e229', hcLight: '#CCCCCC' },
            'Color of whitespace characters in the editor.');

        ColorUtils.registerColor(editorLineNumbers,
            { dark: '#858585', light: '#237893', hcDark: Color.white, hcLight: '#292929' },
            'Color of editor line numbers.');

        ColorUtils.registerColor(deprecatedEditorIndentGuides,
            editorWhitespaces,
            'Color of the editor indentation guides.',
            false,
            '\'editorIndentGuide.background\' is deprecated. Use \'editorIndentGuide.background1\' instead.');

        ColorUtils.registerColor(deprecatedEditorActiveIndentGuides,
            editorWhitespaces,
            'Color of the active editor indentation guides.',
            false,
            '\'editorIndentGuide.activeBackground\' is deprecated. Use \'editorIndentGuide.activeBackground1\' instead.');

        ColorUtils.registerColor(editorIndentGuide1,
            deprecatedEditorIndentGuides,
            'Color of the editor indentation guides (1).');

        ColorUtils.registerColor(editorIndentGuide2,
            '#00000000',
            'Color of the editor indentation guides (2).');

        ColorUtils.registerColor(editorIndentGuide3,
            '#00000000',
            'Color of the editor indentation guides (3).');

        ColorUtils.registerColor(editorIndentGuide4,
            '#00000000',
            'Color of the editor indentation guides (4).');

        ColorUtils.registerColor(editorIndentGuide5,
            '#00000000',
            'Color of the editor indentation guides (5).');

        ColorUtils.registerColor(editorIndentGuide6,
            '#00000000',
            'Color of the editor indentation guides (6).');

        ColorUtils.registerColor(editorActiveIndentGuide1,
            deprecatedEditorActiveIndentGuides,
            'Color of the active editor indentation guides (1).');

        ColorUtils.registerColor(editorActiveIndentGuide2,
            '#00000000',
            'Color of the active editor indentation guides (2).');

        ColorUtils.registerColor(editorActiveIndentGuide3,
            '#00000000',
            'Color of the active editor indentation guides (3).');

        ColorUtils.registerColor(editorActiveIndentGuide4,
            '#00000000',
            'Color of the active editor indentation guides (4).');

        ColorUtils.registerColor(editorActiveIndentGuide5,
            '#00000000',
            'Color of the active editor indentation guides (5).');

        ColorUtils.registerColor(editorActiveIndentGuide6,
            '#00000000',
            'Color of the active editor indentation guides (6).');

        ColorUtils.registerColor(deprecatedEditorActiveLineNumber,
            { dark: '#c6c6c6', light: '#0B216F', hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder },
            'Color of editor active line number',
            false,
            'Id is deprecated. Use \'editorLineNumber.activeForeground\' instead.');

        ColorUtils.registerColor(editorActiveLineNumber,
            deprecatedEditorActiveLineNumber,
            'Color of editor active line number');

        ColorUtils.registerColor(editorDimmedLineNumber,
            null,
            'Color of the final editor line when editor.renderFinalNewline is set to dimmed.');

        ColorUtils.registerColor(editorRuler,
            { dark: '#5A5A5A', light: Color.lightgrey, hcDark: Color.white, hcLight: '#292929' },
            'Color of the editor rulers.');

        ColorUtils.registerColor(editorCodeLensForeground,
            { dark: '#999999', light: '#919191', hcDark: '#999999', hcLight: '#292929' },
            'Foreground color of editor CodeLens');

        ColorUtils.registerColor(editorBracketMatchBackground,
            { dark: '#0064001a', light: '#0064001a', hcDark: '#0064001a', hcLight: '#0000' },
            'Background color behind matching brackets');

        ColorUtils.registerColor(editorBracketMatchBorder,
            { dark: '#888', light: '#B9B9B9', hcDark: BaseColors.contrastBorder, hcLight: BaseColors.contrastBorder },
            'Color for matching brackets boxes');

        ColorUtils.registerColor(editorOverviewRulerBorder,
            { dark: '#7f7f7f4d', light: '#7f7f7f4d', hcDark: '#7f7f7f4d', hcLight: '#666666' },
            'Color of the overview ruler border.');

        ColorUtils.registerColor(editorOverviewRulerBackground,
            null,
            'Background color of the editor overview ruler.');

        ColorUtils.registerColor(editorGutter,
            EditorColors.editorBackground,
            'Background color of the editor gutter. The gutter contains the glyph margins and the line numbers.');

        ColorUtils.registerColor(editorUnnecessaryCodeBorder,
            { dark: null, light: null, hcDark: Color.fromHex('#fff').transparent(0.8), hcLight: BaseColors.contrastBorder },
            'Border color of unnecessary (unused) source code in the editor.');

        ColorUtils.registerColor(editorUnnecessaryCodeOpacity,
            { dark: Color.fromHex('#000a'), light: Color.fromHex('#0007'), hcDark: null, hcLight: null },
            'Opacity of unnecessary (unused) source code in the editor. For example, "#000000c0" will render the code with 75% opacity. For high contrast themes, use the  \'editorUnnecessaryCode.border\' theme color to underline unnecessary code instead of fading it out.');

        ColorUtils.registerColor(ghostTextBorder,
            { dark: null, light: null, hcDark: Color.fromHex('#fff').transparent(0.8), hcLight: Color.fromHex('#292929').transparent(0.8) },
            'Border color of ghost text in the editor.');

        ColorUtils.registerColor(ghostTextForeground,
            { dark: Color.fromHex('#ffffff56'), light: Color.fromHex('#0007'), hcDark: null, hcLight: null },
            'Foreground color of the ghost text in the editor.');

        ColorUtils.registerColor(ghostTextBackground,
            null,
            'Background color of the ghost text in the editor.');

        final rulerRangeDefault = new Color(new RGBA(0, 122, 204, 0.6));

        ColorUtils.registerColor(overviewRulerRangeHighlight,
            rulerRangeDefault,
            'Overview ruler marker color for range highlights. The color must not be opaque so as not to hide underlying decorations.',
            true);

        ColorUtils.registerColor(overviewRulerError,
            { dark: new Color(new RGBA(255, 18, 18, 0.7)), light: new Color(new RGBA(255, 18, 18, 0.7)), hcDark: new Color(new RGBA(255, 50, 50, 1)), hcLight: '#B5200D' },
            'Overview ruler marker color for errors.');

        ColorUtils.registerColor(overviewRulerWarning,
            { dark: EditorColors.editorWarningForeground, light: EditorColors.editorWarningForeground, hcDark: EditorColors.editorWarningBorder, hcLight: EditorColors.editorWarningBorder },
            'Overview ruler marker color for warnings.');

        ColorUtils.registerColor(overviewRulerInfo,
            { dark: EditorColors.editorInfoForeground, light: EditorColors.editorInfoForeground, hcDark: EditorColors.editorInfoBorder, hcLight: EditorColors.editorInfoBorder },
            'Overview ruler marker color for infos.');

        ColorUtils.registerColor(editorBracketHighlightingForeground1,
            { dark: '#FFD700', light: '#0431FAFF', hcDark: '#FFD700', hcLight: '#0431FAFF' },
            'Foreground color of brackets (1). Requires enabling bracket pair colorization.');

        ColorUtils.registerColor(editorBracketHighlightingForeground2,
            { dark: '#DA70D6', light: '#319331FF', hcDark: '#DA70D6', hcLight: '#319331FF' },
            'Foreground color of brackets (2). Requires enabling bracket pair colorization.');

        ColorUtils.registerColor(editorBracketHighlightingForeground3,
            { dark: '#179FFF', light: '#7B3814FF', hcDark: '#87CEFA', hcLight: '#7B3814FF' },
            'Foreground color of brackets (3). Requires enabling bracket pair colorization.');

        ColorUtils.registerColor(editorBracketHighlightingForeground4,
            '#00000000',
            'Foreground color of brackets (4). Requires enabling bracket pair colorization.');

        ColorUtils.registerColor(editorBracketHighlightingForeground5,
            '#00000000',
            'Foreground color of brackets (5). Requires enabling bracket pair colorization.');

        ColorUtils.registerColor(editorBracketHighlightingForeground6,
            '#00000000',
            'Foreground color of brackets (6). Requires enabling bracket pair colorization.');

        ColorUtils.registerColor(editorBracketHighlightingUnexpectedBracketForeground,
            { dark: new Color(new RGBA(255, 18, 18, 0.8)), light: new Color(new RGBA(255, 18, 18, 0.8)), hcDark: 'new Color(new RGBA(255, 50, 50, 1))', hcLight: '#B5200D' },
            'Foreground color of unexpected brackets.');

        ColorUtils.registerColor(editorBracketPairGuideBackground1,
            '#00000000',
            'Background color of inactive bracket pair guides (1). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorBracketPairGuideBackground2,
            '#00000000',
            'Background color of inactive bracket pair guides (2). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorBracketPairGuideBackground3,
            '#00000000',
            'Background color of inactive bracket pair guides (3). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorBracketPairGuideBackground4,
            '#00000000',
            'Background color of inactive bracket pair guides (4). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorBracketPairGuideBackground5,
            '#00000000',
            'Background color of inactive bracket pair guides (5). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorBracketPairGuideBackground6,
            '#00000000',
            'Background color of inactive bracket pair guides (6). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorBracketPairGuideActiveBackground1,
            '#00000000',
            'Background color of active bracket pair guides (1). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorBracketPairGuideActiveBackground2,
            '#00000000',
            'Background color of active bracket pair guides (2). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorBracketPairGuideActiveBackground3,
            '#00000000',
            'Background color of active bracket pair guides (3). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorBracketPairGuideActiveBackground4,
            '#00000000',
            'Background color of active bracket pair guides (4). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorBracketPairGuideActiveBackground5,
            '#00000000',
            'Background color of active bracket pair guides (5). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorBracketPairGuideActiveBackground6,
            '#00000000',
            'Background color of active bracket pair guides (6). Requires enabling bracket pair guides.');

        ColorUtils.registerColor(editorUnicodeHighlightBorder,
            EditorColors.editorWarningForeground,
            'Border color used to highlight unicode characters.');

        ColorUtils.registerColor(editorUnicodeHighlightBackground,
            EditorColors.editorWarningBackground,
            'Background color used to highlight unicode characters.');

        // contains all color rules that used to defined in editor/browser/widget/editor.css
        // TODO: registerThemingParticipant(...) (CSS rules) is not ported: the view reads the colors.

    }

}
