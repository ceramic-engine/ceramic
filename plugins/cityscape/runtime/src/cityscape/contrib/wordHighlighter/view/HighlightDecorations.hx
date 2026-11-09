// Ported from vscode src/vs/editor/contrib/wordHighlighter/browser/highlightDecorations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.wordHighlighter.view;

import cityscape.Cityscape;
import cityscape.common.Languages.DocumentHighlightKind;
import cityscape.common.Model;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ThemeService;
import cityscape.platform.theme.common.colors.BaseColors;
import cityscape.platform.theme.common.colors.EditorColors;

/**
 * The decoration options and colors of the word and selection highlights.
 * The colors are registered by `registerColors` (Monaco registers them when
 * the module loads), the look of the class names (highlightDecorations.css
 * and the theming participant) by `registerStyles`.
 */
class HighlightDecorations {

    public static inline final wordHighlightBackground = 'editor.wordHighlightBackground';
    public static inline final wordHighlightStrongBackground = 'editor.wordHighlightStrongBackground';
    public static inline final wordHighlightTextBackground = 'editor.wordHighlightTextBackground';
    public static inline final wordHighlightBorder = 'editor.wordHighlightBorder';
    public static inline final wordHighlightStrongBorder = 'editor.wordHighlightStrongBorder';
    public static inline final wordHighlightTextBorder = 'editor.wordHighlightTextBorder';
    public static inline final overviewRulerWordHighlightForeground = 'editorOverviewRuler.wordHighlightForeground';
    public static inline final overviewRulerWordHighlightStrongForeground = 'editorOverviewRuler.wordHighlightStrongForeground';
    public static inline final overviewRulerWordHighlightTextForeground = 'editorOverviewRuler.wordHighlightTextForeground';
    static inline final minimapSelectionOccurrenceHighlight = 'minimap.selectionOccurrenceHighlight';

    public static function registerColors(context:Cityscape):Void {
        final nls = context.nls;
        ColorUtils.registerColor(wordHighlightBackground, {dark: '#575757B8', light: '#57575740', hcDark: null, hcLight: null}, nls.localize('wordHighlight', 'Background color of a symbol during read-access, like reading a variable. The color must not be opaque so as not to hide underlying decorations.'), true);
        ColorUtils.registerColor(wordHighlightStrongBackground, {dark: '#004972B8', light: '#0e639c40', hcDark: null, hcLight: null}, nls.localize('wordHighlightStrong', 'Background color of a symbol during write-access, like writing to a variable. The color must not be opaque so as not to hide underlying decorations.'), true);
        ColorUtils.registerColor(wordHighlightTextBackground, wordHighlightBackground, nls.localize('wordHighlightText', 'Background color of a textual occurrence for a symbol. The color must not be opaque so as not to hide underlying decorations.'), true);
        ColorUtils.registerColor(wordHighlightBorder, {light: null, dark: null, hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder}, nls.localize('wordHighlightBorder', 'Border color of a symbol during read-access, like reading a variable.'));
        ColorUtils.registerColor(wordHighlightStrongBorder, {light: null, dark: null, hcDark: BaseColors.activeContrastBorder, hcLight: BaseColors.activeContrastBorder}, nls.localize('wordHighlightStrongBorder', 'Border color of a symbol during write-access, like writing to a variable.'));
        ColorUtils.registerColor(wordHighlightTextBorder, wordHighlightBorder, nls.localize('wordHighlightTextBorder', "Border color of a textual occurrence for a symbol."));
        ColorUtils.registerColor(overviewRulerWordHighlightForeground, '#A0A0A0CC', nls.localize('overviewRulerWordHighlightForeground', 'Overview ruler marker color for symbol highlights. The color must not be opaque so as not to hide underlying decorations.'), true);
        ColorUtils.registerColor(overviewRulerWordHighlightStrongForeground, '#C0A0C0CC', nls.localize('overviewRulerWordHighlightStrongForeground', 'Overview ruler marker color for write-access symbol highlights. The color must not be opaque so as not to hide underlying decorations.'), true);
        ColorUtils.registerColor(overviewRulerWordHighlightTextForeground, EditorColors.overviewRulerSelectionHighlightForeground, nls.localize('overviewRulerWordHighlightTextForeground', 'Overview ruler marker color of a textual occurrence for a symbol. The color must not be opaque so as not to hide underlying decorations.'), true);
    }

    /**
     * highlightDecorations.css: a background and a 1px border of the theme
     * colors (the border is drawn only when the theme gives it a color).
     * `selectionHighlight` takes the focused editor's look
     * (`.monaco-editor .focused .selectionHighlight`).
     */
    public static function registerStyles(context:Cityscape):Void {
        final styles = context.decorationStyles;
        inline function define(className:String, background:String, border:String) {
            if (styles.get(className) == null) {
                context.registerDecorationStyle(className, {
                    background: {id: background},
                    border: {color: {id: border}, width: 1}
                });
            }
        }
        define('selectionHighlight', EditorColors.editorSelectionHighlight, EditorColors.editorSelectionHighlightBorder);
        define('wordHighlight', wordHighlightBackground, wordHighlightBorder);
        define('wordHighlightStrong', wordHighlightStrongBackground, wordHighlightStrongBorder);
        define('wordHighlightText', wordHighlightTextBackground, wordHighlightTextBorder);
    }

    static var _options:Null<Array<ModelDecorationOptions>> = null;

    static function options():Array<ModelDecorationOptions> {
        if (_options == null) {
            _options = [
                // _WRITE_OPTIONS
                ModelDecorationOptions.register({
                    description: 'word-highlight-strong',
                    stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
                    className: 'wordHighlightStrong',
                    overviewRuler: {
                        color: ThemeService.themeColorFromId(overviewRulerWordHighlightStrongForeground),
                        position: OverviewRulerLane.Center
                    },
                    minimap: {
                        color: ThemeService.themeColorFromId(minimapSelectionOccurrenceHighlight),
                        position: MinimapPosition.Inline
                    },
                }),
                // _TEXT_OPTIONS
                ModelDecorationOptions.register({
                    description: 'word-highlight-text',
                    stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
                    className: 'wordHighlightText',
                    overviewRuler: {
                        color: ThemeService.themeColorFromId(overviewRulerWordHighlightTextForeground),
                        position: OverviewRulerLane.Center
                    },
                    minimap: {
                        color: ThemeService.themeColorFromId(minimapSelectionOccurrenceHighlight),
                        position: MinimapPosition.Inline
                    },
                }),
                // _SELECTION_HIGHLIGHT_OPTIONS
                ModelDecorationOptions.register({
                    description: 'selection-highlight-overview',
                    stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
                    className: 'selectionHighlight',
                    overviewRuler: {
                        color: ThemeService.themeColorFromId(EditorColors.overviewRulerSelectionHighlightForeground),
                        position: OverviewRulerLane.Center
                    },
                    minimap: {
                        color: ThemeService.themeColorFromId(minimapSelectionOccurrenceHighlight),
                        position: MinimapPosition.Inline
                    },
                }),
                // _SELECTION_HIGHLIGHT_OPTIONS_NO_OVERVIEW
                ModelDecorationOptions.register({
                    description: 'selection-highlight',
                    stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
                    className: 'selectionHighlight',
                }),
                // _REGULAR_OPTIONS
                ModelDecorationOptions.register({
                    description: 'word-highlight',
                    stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
                    className: 'wordHighlight',
                    overviewRuler: {
                        color: ThemeService.themeColorFromId(overviewRulerWordHighlightForeground),
                        position: OverviewRulerLane.Center
                    },
                    minimap: {
                        color: ThemeService.themeColorFromId(minimapSelectionOccurrenceHighlight),
                        position: MinimapPosition.Inline
                    },
                })
            ];
        }
        return _options;
    }

    public static function getHighlightDecorationOptions(kind:Null<DocumentHighlightKind>):ModelDecorationOptions {
        if (kind == DocumentHighlightKind.Write) {
            return options()[0];
        }
        else if (kind == DocumentHighlightKind.Text) {
            return options()[1];
        }
        else {
            return options()[4];
        }
    }

    public static function getSelectionHighlightDecorationOptions(hasSemanticHighlights:Bool):ModelDecorationOptions {
        // Show in overviewRuler only if model has no semantic highlighting
        return (hasSemanticHighlights ? options()[3] : options()[2]);
    }

}
